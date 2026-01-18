/// Pipeline orchestration for Synheart Flux
///
/// This module provides the public API for Synheart Flux.
/// It uses FFI bindings to call the native Rust Flux library.

import 'dart:convert';

import 'ffi/flux_ffi.dart';
import 'types.dart';

/// Convert raw WHOOP JSON payload to HSI-compliant daily payloads.
///
/// [rawJson] - Raw WHOOP API response JSON
/// [timezone] - User's timezone (e.g., "America/New_York")
/// [deviceId] - Unique device identifier
///
/// Returns list of HSI JSON payloads (one per day in the input)
///
/// Throws [FluxNotAvailableException] if native Flux library is not loaded.
///
/// Example:
/// ```dart
/// final hsiPayloads = whoopToHsiDaily(
///   whoopJson,
///   'America/New_York',
///   'device-123',
/// );
/// ```
List<String> whoopToHsiDaily(
  String rawJson,
  String timezone,
  String deviceId,
) {
  final native = FluxNative.create();
  if (native == null) {
    throw FluxNotAvailableException(FluxFfi.loadError);
  }

  final resultJson = native.whoopToHsiDaily(rawJson, timezone, deviceId);
  return _parseJsonArray(resultJson);
}

/// Convert raw Garmin JSON payload to HSI-compliant daily payloads.
///
/// [rawJson] - Raw Garmin API response JSON
/// [timezone] - User's timezone (e.g., "America/Los_Angeles")
/// [deviceId] - Unique device identifier
///
/// Returns list of HSI JSON payloads (one per day in the input)
///
/// Throws [FluxNotAvailableException] if native Flux library is not loaded.
///
/// Example:
/// ```dart
/// final hsiPayloads = garminToHsiDaily(
///   garminJson,
///   'America/Los_Angeles',
///   'garmin-device-456',
/// );
/// ```
List<String> garminToHsiDaily(
  String rawJson,
  String timezone,
  String deviceId,
) {
  final native = FluxNative.create();
  if (native == null) {
    throw FluxNotAvailableException(FluxFfi.loadError);
  }

  final resultJson = native.garminToHsiDaily(rawJson, timezone, deviceId);
  return _parseJsonArray(resultJson);
}

/// Check if the native Flux library is available
bool get isFluxAvailable => FluxNative.isAvailable;

/// Get the error message if Flux failed to load
String? get fluxLoadError => FluxFfi.loadError;

/// Parse a JSON array string into a list of JSON strings
List<String> _parseJsonArray(String jsonArrayStr) {
  final decoded = jsonDecode(jsonArrayStr);
  if (decoded is List) {
    return decoded.map((item) => jsonEncode(item)).toList();
  }
  // Single object, wrap in list
  return [jsonArrayStr];
}

/// Stateful processor for incremental processing with persistent baselines.
///
/// Use this when you need to maintain baselines across multiple API calls.
/// This class wraps the native Rust FluxProcessor via FFI.
///
/// Example:
/// ```dart
/// final processor = FluxProcessor();
///
/// // Process WHOOP data
/// final results = processor.processWhoop(whoopJson, 'America/New_York', 'device-123');
///
/// // Save baselines for later
/// final savedBaselines = processor.saveBaselines();
///
/// // ... later ...
///
/// // Load baselines and continue processing
/// processor.loadBaselines(savedBaselines);
/// final moreResults = processor.processWhoop(moreWhoopJson, 'America/New_York', 'device-123');
///
/// // Don't forget to dispose when done
/// processor.dispose();
/// ```
class FluxProcessor {
  FluxProcessorNative? _native;

  /// Create a new processor with default settings (14-day baseline window)
  ///
  /// Throws [FluxNotAvailableException] if native Flux library is not loaded.
  FluxProcessor() : this.withBaselineWindow(14);

  /// Create a processor with a specific baseline window size
  ///
  /// Throws [FluxNotAvailableException] if native Flux library is not loaded.
  FluxProcessor.withBaselineWindow(int windowDays) {
    _native = FluxProcessorNative.create(baselineWindowDays: windowDays);
    if (_native == null) {
      throw FluxNotAvailableException(FluxFfi.loadError);
    }
  }

  /// Load baseline state from JSON
  void loadBaselines(String json) {
    _checkAvailable();
    _native!.loadBaselines(json);
  }

  /// Save baseline state to JSON
  String saveBaselines() {
    _checkAvailable();
    return _native!.saveBaselines();
  }

  /// Get current baselines as JSON
  Baselines get currentBaselines {
    _checkAvailable();
    final json = _native!.saveBaselines();
    final data = jsonDecode(json) as Map<String, dynamic>;
    return Baselines.fromJson(data);
  }

  /// Process WHOOP payload with persistent baselines
  ///
  /// [rawJson] - Raw WHOOP API response JSON
  /// [timezone] - User's timezone (e.g., "America/New_York")
  /// [deviceId] - Unique device identifier
  ///
  /// Returns list of HSI JSON payloads
  List<String> processWhoop(
    String rawJson,
    String timezone,
    String deviceId,
  ) {
    _checkAvailable();
    final resultJson = _native!.processWhoop(rawJson, timezone, deviceId);
    return _parseJsonArray(resultJson);
  }

  /// Process Garmin payload with persistent baselines
  ///
  /// [rawJson] - Raw Garmin API response JSON
  /// [timezone] - User's timezone (e.g., "America/Los_Angeles")
  /// [deviceId] - Unique device identifier
  ///
  /// Returns list of HSI JSON payloads
  List<String> processGarmin(
    String rawJson,
    String timezone,
    String deviceId,
  ) {
    _checkAvailable();
    final resultJson = _native!.processGarmin(rawJson, timezone, deviceId);
    return _parseJsonArray(resultJson);
  }

  /// Dispose of the native processor resources
  ///
  /// After calling dispose, this processor can no longer be used.
  void dispose() {
    _native?.dispose();
    _native = null;
  }

  void _checkAvailable() {
    if (_native == null || _native!.isDisposed) {
      throw StateError('FluxProcessor has been disposed or is not available');
    }
  }
}

/// Exception thrown when the native Flux library is not available
class FluxNotAvailableException implements Exception {
  final String message;

  FluxNotAvailableException([String? loadError])
      : message = loadError != null
            ? 'Native Flux library not available: $loadError'
            : 'Native Flux library not available. Ensure the Flux native '
                'libraries are bundled with your application. '
                'See vendor/flux/README.md for setup instructions.';

  @override
  String toString() => 'FluxNotAvailableException: $message';
}
