// Copyright 2025 Synheart. RAMEN gRPC client per SDK Integration Guide.

import 'dart:async';
import 'dart:convert';

import 'package:fixnum/fixnum.dart';
import 'package:grpc/grpc.dart';
import 'generated/google_protobuf_timestamp.pb.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'generated/ramen.pbgrpc.dart';

const String _lastSeqKey = 'ramen_last_acknowledged_seq';

/// Connection state for RAMEN. Use [connectionState] to know when the
/// connection is actually established (first server message) or lost.
enum RamenConnectionState {
  /// Connecting: stream started, waiting for first server message.
  connecting,

  /// Connected: at least one Event or HeartbeatAck received from server.
  connected,

  /// Stream ended or error; client may be reconnecting.
  disconnected,

  /// Reconnecting: backoff delay before next connect().
  reconnecting,
}

/// Parsed event from RAMEN (payload is JSON).
class RamenEvent {
  RamenEvent({
    required this.eventId,
    required this.seq,
    required this.payloadJson,
    this.payload,
  });

  final String eventId;
  final Int64 seq;
  final String payloadJson;
  final Map<String, dynamic>? payload;

  static RamenEvent fromEnvelope(EventEnvelope envelope) {
    Map<String, dynamic>? payload;
    try {
      if (envelope.payload.isNotEmpty) {
        payload = jsonDecode(envelope.payload) as Map<String, dynamic>?;
      }
    } catch (_) {
      /* leave payload null */
    }
    return RamenEvent(
      eventId: envelope.eventId,
      seq: envelope.seq,
      payloadJson: envelope.payload,
      payload: payload,
    );
  }
}

/// RAMEN gRPC client: connection to Synheart RAMEN with last_acknowledged_seq,
/// device_id, user_id; security headers (X-app-id, X-api-key) on every request;
/// seq saved in local storage; heartbeat every 30s, force-close after 2 missed.
class RamenClient {
  RamenClient({
    required this.host,
    this.port = 443,
    this.appId = '',
    this.apiKey = '',
    required this.deviceId,
    this.userId = '',
    this.useTls = true,
    this.heartbeatInterval = const Duration(seconds: 30),
    this.heartbeatMissedAttempts = 2,
  });

  final String host;
  final int port;
  final String appId;
  final String apiKey;
  final String deviceId;
  /// User identifier sent in SubscribeRequest (in addition to X-app-id and X-api-key).
  final String userId;
  final bool useTls;
  final Duration heartbeatInterval;
  final int heartbeatMissedAttempts;

  ClientChannel? _channel;
  RamenServiceClient? _client;
  StreamSubscription<ServerMessage>? _subscription;
  StreamController<ClientMessage>? _requestController;
  final StreamController<RamenEvent> _eventController =
      StreamController<RamenEvent>.broadcast();
  final StreamController<RamenConnectionState> _stateController =
      StreamController<RamenConnectionState>.broadcast();
  Timer? _heartbeatTimer;
  int _heartbeatsWithoutAck = 0;
  bool _closed = false;
  int _backoffSeconds = 1;
  bool _hasEmittedConnected = false;

  /// Stream of connection state. Emits [RamenConnectionState.connected] when
  /// the first Event or HeartbeatAck is received (connection is successful).
  /// Emits [RamenConnectionState.disconnected] on stream error/done.
  Stream<RamenConnectionState> get connectionState => _stateController.stream;

  /// Stream of parsed events (payload as JSON). Process and Ack(seq) is done
  /// inside; use [lastSeq] for idempotency if needed.
  Stream<RamenEvent> get events => _eventController.stream;

  /// Last acknowledged seq (from local storage). Used as last_acknowledged_seq
  /// in SubscribeRequest (0 if first time).
  Future<Int64> get lastSeq async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getInt(_lastSeqKey);
    return v != null ? Int64(v) : Int64.ZERO;
  }

  /// gRPC call options: X-app-id and X-api-key on every request (auth).
  /// Passed to subscribe() so the connection carries these headers.
  CallOptions _callOptions() {
    final meta = <String, String>{};
    if (appId.isNotEmpty) meta['x-app-id'] = appId;
    if (apiKey.isNotEmpty) meta['x-api-key'] = apiKey;
    return CallOptions(metadata: meta);
  }

  void _emitConnectedIfFirst() {
    if (!_hasEmittedConnected && !_closed) {
      _hasEmittedConnected = true;
      _backoffSeconds = 1; // reset backoff after successful connection
      _stateController.add(RamenConnectionState.connected);
    }
  }

  /// Start the subscription loop. Sends SubscribeRequest with
  /// last_acknowledged_seq (from local storage, or 0 if first time), device_id,
  /// user_id, app_id; X-app-id and X-api-key are sent via [_callOptions] on the connection.
  /// On each Event, sends Ack(seq) and saves seq to local storage.
  /// Every 30s sends Heartbeat(timestamp=Timestamp.fromDateTime(utc)); if HeartbeatAck not received
  /// after 2 attempts, force-closes and reconnects.
  Future<void> connect() async {
    if (_closed) return;
    _hasEmittedConnected = false;
    _stateController.add(RamenConnectionState.connecting);

    // Cleanup previous connection: cancel subscription and close previous request stream
    await _subscription?.cancel();
    await _requestController?.close();
    _requestController = StreamController<ClientMessage>(); // single-subscription, not broadcast

    _channel = useTls
        ? ClientChannel(host, port: port, options: const ChannelOptions(credentials: ChannelCredentials.secure()))
        : ClientChannel(host, port: port);
    _client = RamenServiceClient(_channel!);

    final lastAckSeq = await lastSeq;
    final subscribe = ClientMessage()
      ..subscribe = (SubscribeRequest()
        ..appId = appId
        ..lastSeq = lastAckSeq
        ..deviceId = deviceId
        ..userId = userId);
    // One SubscribeRequest per connection, then only Ack/Heartbeat on _requestController
    Stream<ClientMessage> buildRequestStream() async* {
      yield subscribe;
      yield* _requestController!.stream;
    }

    final responseStream = _client!.subscribe(
      buildRequestStream(),
      options: _callOptions(), // X-app-id and X-api-key on every request
    );

    _heartbeatsWithoutAck = 0;
    _startHeartbeatTimer();

    _subscription = responseStream.listen(
      (ServerMessage msg) {
        switch (msg.whichMessage()) {
          case ServerMessage_Message.event:
            _emitConnectedIfFirst();
            _onEvent(msg.event);
            break;
          case ServerMessage_Message.heartbeatAck:
            _emitConnectedIfFirst();
            _heartbeatsWithoutAck = 0;
            break;
          case ServerMessage_Message.notSet:
            break;
        }
      },
      onError: (e, st) {
        _stopHeartbeatTimer();
        if (!_closed) _stateController.add(RamenConnectionState.disconnected);
        _scheduleReconnect();
      },
      onDone: () {
        _stopHeartbeatTimer();
        if (!_closed) {
          _stateController.add(RamenConnectionState.disconnected);
          _scheduleReconnect();
        }
      },
      cancelOnError: false,
    );
  }

  void _onEvent(EventEnvelope envelope) {
    final ramenEvent = RamenEvent.fromEnvelope(envelope);
    _eventController.add(ramenEvent);
    _sendAck(envelope.seq);
    _persistLastSeq(envelope.seq);
  }

  void _sendAck(Int64 seq) {
    _requestController?.add(ClientMessage()..ack = (Ack()..seq = seq));
  }

  /// Save seq to local storage for last_acknowledged_seq on next connection.
  Future<void> _persistLastSeq(Int64 seq) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSeqKey, seq.toInt());
  }

  /// Every 30s send Heartbeat(timestamp=now()). After 2 missed HeartbeatAck,
  /// force-close connection and reconnect.
  void _startHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) {
      _heartbeatsWithoutAck++;
      if (_heartbeatsWithoutAck >= heartbeatMissedAttempts) {
        _stopHeartbeatTimer();
        _subscription?.cancel();
        _scheduleReconnect();
        return;
      }
      final hb = ClientMessage()
        ..heartbeat = (Heartbeat()
          ..timestamp = Timestamp.fromDateTime(DateTime.now().toUtc()));
      _requestController?.add(hb);
    });
  }

  void _stopHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _scheduleReconnect() {
    if (_closed) return;
    _stateController.add(RamenConnectionState.reconnecting);
    final delay = _backoffSeconds;
    _backoffSeconds = _backoffSeconds > 32 ? 32 : _backoffSeconds * 2;
    Future.delayed(Duration(seconds: delay), () async {
      if (_closed) return;
      await _channel?.shutdown();
      await connect();
    });
  }

  /// Close the client and stop reconnecting.
  Future<void> close() async {
    _closed = true;
    _stopHeartbeatTimer();
    await _subscription?.cancel();
    await _requestController?.close();
    _requestController = null;
    await _channel?.shutdown();
    await _eventController.close();
    await _stateController.close();
  }
}
