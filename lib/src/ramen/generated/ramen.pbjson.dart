//
//  Generated code. Do not modify.
//  source: ramen.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use subscribeRequestDescriptor instead')
const SubscribeRequest$json = {
  '1': 'SubscribeRequest',
  '2': [
    {'1': 'last_seq', '3': 1, '4': 1, '5': 3, '10': 'lastSeq'},
    {'1': 'device_id', '3': 2, '4': 1, '5': 9, '10': 'deviceId'},
    {'1': 'user_id', '3': 3, '4': 1, '5': 9, '10': 'userId'},
  ],
};

/// Descriptor for `SubscribeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List subscribeRequestDescriptor = $convert.base64Decode(
    'ChBTdWJzY3JpYmVSZXF1ZXN0EhkKCGxhc3Rfc2VxGAEgASgDUgdsYXN0U2VxEhsKCWRldmljZV'
    '9pZBgCIAEoCVIIZGV2aWNlSWQ=');

@$core.Deprecated('Use ackDescriptor instead')
const Ack$json = {
  '1': 'Ack',
  '2': [
    {'1': 'seq', '3': 1, '4': 1, '5': 3, '10': 'seq'},
  ],
};

/// Descriptor for `Ack`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List ackDescriptor = $convert.base64Decode(
    'CgNBY2sSEAoDc2VxGAEgASgDUgNzZXE=');

@$core.Deprecated('Use heartbeatDescriptor instead')
const Heartbeat$json = {
  '1': 'Heartbeat',
  '2': [
    {'1': 'timestamp', '3': 1, '4': 1, '5': 3, '10': 'timestamp'},
  ],
};

/// Descriptor for `Heartbeat`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List heartbeatDescriptor = $convert.base64Decode(
    'CglIZWFydGJlYXQSHAoJdGltZXN0YW1wGAEgASgDUgl0aW1lc3RhbXA=');

@$core.Deprecated('Use clientMessageDescriptor instead')
const ClientMessage$json = {
  '1': 'ClientMessage',
  '2': [
    {'1': 'subscribe', '3': 1, '4': 1, '5': 11, '6': '.ramen.SubscribeRequest', '9': 0, '10': 'subscribe'},
    {'1': 'ack', '3': 2, '4': 1, '5': 11, '6': '.ramen.Ack', '9': 0, '10': 'ack'},
    {'1': 'heartbeat', '3': 3, '4': 1, '5': 11, '6': '.ramen.Heartbeat', '9': 0, '10': 'heartbeat'},
  ],
  '8': [
    {'1': 'message'},
  ],
};

/// Descriptor for `ClientMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List clientMessageDescriptor = $convert.base64Decode(
    'Cg1DbGllbnRNZXNzYWdlEjcKCXN1YnNjcmliZRgBIAEoCzIXLnJhbWVuLlN1YnNjcmliZVJlcX'
    'Vlc3RIAFIJc3Vic2NyaWJlEh4KA2FjaxgCIAEoCzIKLnJhbWVuLkFja0gAUgNhY2sSMAoJaGVh'
    'cnRiZWF0GAMgASgLMhAucmFtZW4uSGVhcnRiZWF0SABSCWhlYXJ0YmVhdEIJCgdtZXNzYWdl');

@$core.Deprecated('Use eventEnvelopeDescriptor instead')
const EventEnvelope$json = {
  '1': 'EventEnvelope',
  '2': [
    {'1': 'event_id', '3': 1, '4': 1, '5': 9, '10': 'eventId'},
    {'1': 'seq', '3': 2, '4': 1, '5': 3, '10': 'seq'},
    {'1': 'payload', '3': 3, '4': 1, '5': 9, '10': 'payload'},
  ],
};

/// Descriptor for `EventEnvelope`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List eventEnvelopeDescriptor = $convert.base64Decode(
    'Cg1FdmVudEVudmVsb3BlEhkKCGV2ZW50X2lkGAEgASgJUgdldmVudElkEhAKA3NlcRgCIAEoA1'
    'IDc2VxEhgKB3BheWxvYWQYAyABKAlSB3BheWxvYWQ=');

@$core.Deprecated('Use heartbeatAckDescriptor instead')
const HeartbeatAck$json = {
  '1': 'HeartbeatAck',
  '2': [
    {'1': 'rtt_ms', '3': 1, '4': 1, '5': 3, '10': 'rttMs'},
  ],
};

/// Descriptor for `HeartbeatAck`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List heartbeatAckDescriptor = $convert.base64Decode(
    'CgxIZWFydGJlYXRBY2sSFQoGcnR0X21zGAEgASgDUgVydHRNcw==');

@$core.Deprecated('Use serverMessageDescriptor instead')
const ServerMessage$json = {
  '1': 'ServerMessage',
  '2': [
    {'1': 'event', '3': 1, '4': 1, '5': 11, '6': '.ramen.EventEnvelope', '9': 0, '10': 'event'},
    {'1': 'heartbeat_ack', '3': 2, '4': 1, '5': 11, '6': '.ramen.HeartbeatAck', '9': 0, '10': 'heartbeatAck'},
  ],
  '8': [
    {'1': 'message'},
  ],
};

/// Descriptor for `ServerMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List serverMessageDescriptor = $convert.base64Decode(
    'Cg1TZXJ2ZXJNZXNzYWdlEiwKBWV2ZW50GAEgASgLMhQucmFtZW4uRXZlbnRFbnZlbG9wZUgAUg'
    'VldmVudBI6Cg1oZWFydGJlYXRfYWNrGAIgASgLMhMucmFtZW4uSGVhcnRiZWF0QWNrSABSDGhl'
    'YXJ0YmVhdEFja0IJCgdtZXNzYWdl');

