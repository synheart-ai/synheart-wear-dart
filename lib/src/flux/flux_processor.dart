/// Pipeline orchestration for Synheart Flux
///
/// This module provides the public API for Synheart Flux.
/// Flux is optional - if the native library is not available, functions
/// gracefully return null instead of throwing exceptions.

import 'dart:convert';

import 'ffi/flux_ffi.dart';
import 'types.dart';

/// Convert raw WHOOP JSON payload to HSI 1.0 compliant daily payloads.
///
/// [rawJson] - Raw WHOOP API response JSON
/// [timezone] - User's timezone (e.g., "America/New_York")
/// [deviceId] - Unique device identifier
///
/// Returns list of HSI JSON payloads (one per day in the input),
/// or null if Flux is not available (graceful degradation).
///
/// Example:
/// ```dart
/// final hsiPayloads = whoopToHsiDaily(
///   whoopJson,
///   'America/New_York',
///   'device-123',
/// );
/// if (hsiPayloads == null) {
///   print('Flux not available');
/// }
/// ```
List<String>? whoopToHsiDaily(
  String rawJson,
  String timezone,
  String deviceId,
) {
  final native = FluxNative.create();
  if (native == null) {
    print('whoopToHsiDaily: Flux native library not available');
    return null;
  }

  final resultJson = native.whoopToHsiDaily(rawJson, timezone, deviceId);
  if (resultJson == null) {
    return null;
  }
  return _parseJsonArray(resultJson);
}

/// Convert raw Garmin JSON payload to HSI 1.0 compliant daily payloads.
///
/// [rawJson] - Raw Garmin API response JSON
/// [timezone] - User's timezone (e.g., "America/Los_Angeles")
/// [deviceId] - Unique device identifier
///
/// Returns list of HSI JSON payloads (one per day in the input),
/// or null if Flux is not available (graceful degradation).
///
/// Example:
/// ```dart
/// final hsiPayloads = garminToHsiDaily(
///   garminJson,
///   'America/Los_Angeles',
///   'garmin-device-456',
/// );
/// if (hsiPayloads == null) {
///   print('Flux not available');
/// }
/// ```
List<String>? garminToHsiDaily(
  String rawJson,
  String timezone,
  String deviceId,
) {
  final native = FluxNative.create();
  if (native == null) {
    print('garminToHsiDaily: Flux native library not available');
    return null;
  }

  final resultJson = native.garminToHsiDaily(rawJson, timezone, deviceId);
  if (resultJson == null) {
    return null;
  }
  return _parseJsonArray(resultJson);
}

/// Check if the native Flux library is available
bool get isFluxAvailable => FluxNative.isAvailable;

/// Get the error message if Flux failed to load
String? get fluxLoadError => FluxFfi.loadError;

/// Parse a JSON array string into a list of JSON strings
List<String> _parseJsonArray(String jsonArrayStr) {
  try {
    final decoded = jsonDecode(jsonArrayStr);
    if (decoded is List) {
      return decoded.map((item) => jsonEncode(item)).toList();
    }
    // Single object, wrap in list
    return [jsonArrayStr];
  } catch (e) {
    print('_parseJsonArray: Failed to parse JSON: $e');
    return [];
  }
}

/// Stateful processor for incremental processing with persistent baselines.
///
/// Use this when you need to maintain baselines across multiple API calls.
/// This class wraps the native Rust FluxProcessor via FFI.
///
/// Flux is optional - if the native library is not available:
/// - `isAvailable` returns false
/// - Processing methods return null
/// - Baseline methods return null/false
///
/// Example:
/// ```dart
/// final processor = FluxProcessor();
///
/// if (!processor.isAvailable) {
///   print('Flux not available, using fallback');
///   return;
/// }
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
/// processor.loadBaselines(savedBaselines ?? '{}');
/// final moreResults = processor.processWhoop(moreWhoopJson, 'America/New_York', 'device-123');
///
/// // Don't forget to dispose when done
/// processor.dispose();
/// ```
class FluxProcessor {
  FluxProcessorNative? _native;

  /// Create a new processor with default settings (14-day baseline window)
  ///
  /// If Flux native library is not available, `isAvailable` will return false
  /// and all processing methods will return null (graceful degradation).
  FluxProcessor() : this.withBaselineWindow(14);

  /// Create a processor with a specific baseline window size
  ///
  /// If Flux native library is not available, `isAvailable` will return false
  /// and all processing methods will return null (graceful degradation).
  FluxProcessor.withBaselineWindow(int windowDays) {
    _native = FluxProcessorNative.create(baselineWindowDays: windowDays);
    if (_native == null) {
      print('FluxProcessor: Native library not available, running in degraded mode');
    }
  }

  /// Check if Flux native library is available
  bool get isAvailable => _native != null && !_native!.isDisposed;

  /// Check if Flux native library is available (static check)
  static bool get isFluxAvailable => FluxProcessorNative.isAvailable;

  /// Load baseline state from JSON
  /// Returns true if successful, false if failed or Flux unavailable
  bool loadBaselines(String json) {
    if (_native == null || _native!.isDisposed) {
      print('FluxProcessor: Cannot load baselines - not available');
      return false;
    }
    return _native!.loadBaselines(json);
  }

  /// Save baseline state to JSON
  /// Returns null if Flux is not available
  String? saveBaselines() {
    if (_native == null || _native!.isDisposed) {
      print('FluxProcessor: Cannot save baselines - not available');
      return null;
    }
    return _native!.saveBaselines();
  }

  /// Get current baselines as typed object
  /// Returns null if Flux is not available
  Baselines? get currentBaselines {
    final json = saveBaselines();
    if (json == null) return null;
    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      return Baselines.fromJson(data);
    } catch (e) {
      print('FluxProcessor: Failed to parse baselines: $e');
      return null;
    }
  }

  /// Process WHOOP payload with persistent baselines
  ///
  /// [rawJson] - Raw WHOOP API response JSON
  /// [timezone] - User's timezone (e.g., "America/New_York")
  /// [deviceId] - Unique device identifier
  ///
  /// Returns list of HSI JSON payloads, or null if Flux is not available
  List<String>? processWhoop(
    String rawJson,
    String timezone,
    String deviceId,
  ) {
    if (_native == null || _native!.isDisposed) {
      print('FluxProcessor: Cannot process WHOOP - not available');
      return null;
    }
    final resultJson = _native!.processWhoop(rawJson, timezone, deviceId);
    if (resultJson == null) return null;
    return _parseJsonArray(resultJson);
  }

  /// Process Garmin payload with persistent baselines
  ///
  /// [rawJson] - Raw Garmin API response JSON
  /// [timezone] - User's timezone (e.g., "America/Los_Angeles")
  /// [deviceId] - Unique device identifier
  ///
  /// Returns list of HSI JSON payloads, or null if Flux is not available
  List<String>? processGarmin(
    String rawJson,
    String timezone,
    String deviceId,
  ) {
    if (_native == null || _native!.isDisposed) {
      print('FluxProcessor: Cannot process Garmin - not available');
      return null;
    }
    final resultJson = _native!.processGarmin(rawJson, timezone, deviceId);
    if (resultJson == null) return null;
    return _parseJsonArray(resultJson);
  }

  /// Dispose of the native processor resources
  ///
  /// After calling dispose, this processor can no longer be used.
  void dispose() {
    _native?.dispose();
    _native = null;
  }
}

/// Exception thrown when the native Flux library is not available
/// @deprecated Use null checks instead - Flux now uses graceful degradation
@Deprecated('Use null checks instead - Flux now uses graceful degradation')
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
