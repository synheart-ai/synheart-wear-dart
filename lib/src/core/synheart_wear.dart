import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../adapters/wear_adapter.dart';
import 'models.dart';
import '../normalization/normalizer.dart';
import '../adapters/apple_healthkit.dart';
import '../adapters/fitbit.dart';
import 'config.dart';
import 'consent_manager.dart';
import 'local_cache.dart';
import 'logger.dart';
import '../flux/flux_processor.dart';
import '../flux/types.dart';

/// Main SynheartWear SDK class implementing RFC specifications
class SynheartWear {
  bool _initialized = false;
  final SynheartWearConfig config;
  final Normalizer _normalizer;
  StreamController<WearMetrics>? _hrStreamController;
  StreamController<WearMetrics>? _hrvStreamController;
  StreamController<HsiPayload>? _fluxStreamController;
  Timer? _streamTimer;

  final Map<DeviceAdapter, WearAdapter> _adapterRegistry;

  Timer? _hrvTimer; // Separate timer for HRV
  Timer? _fluxTimer; // Timer for Flux snapshots

  /// Flux processor for HSI signal processing (lazy initialized)
  FluxProcessor? _fluxProcessor;

  SynheartWear({
    SynheartWearConfig? config,
    Map<DeviceAdapter, WearAdapter>? adapters,
  }) : config = config ?? const SynheartWearConfig(),
       _normalizer = Normalizer(),
       _adapterRegistry =
           adapters ??
           {
             DeviceAdapter.appleHealthKit: AppleHealthKitAdapter(),
             DeviceAdapter.fitbit: FitbitAdapter(),
           };

  /// Initialize the SDK with permissions and setup
  ///
  /// This method will:
  /// 1. Request necessary permissions
  /// 2. Initialize adapters
  /// 3. Fetch and validate actual wearable data
  /// 4. Verify data is not empty and not stale
  ///
  /// Throws [SynheartWearError] if:
  /// - Permissions are denied
  /// - No wearable data is available
  /// - Latest data is stale (older than 24 hours)
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    try {
      // Request necessary permissions

      await _requestPermissions();

      // Initialize adapters

      await _initializeAdapters();

      final testData = <WearMetrics?>[];
      for (final adapter in _enabledAdapters()) {
        try {
          // Try to fetch recent data (last 7 days)
          final data = await adapter.readSnapshot(
            isRealTime: false,
            startTime: DateTime.now().subtract(const Duration(days: 7)),
            endTime: DateTime.now(),
          );
          if (data != null) {
          } else {}

          testData.add(data);
        } catch (e) {
          // Log warning but continue checking other adapters
        }
      }

      // Merge and validate the test data

      final mergedTestData = _normalizer.mergeSnapshots(testData);

      // Check if data is empty

      if (!mergedTestData.hasValidData || mergedTestData.metrics.isEmpty) {
        // if (mergedTestData.hasValidData || mergedTestData.metrics.isNotEmpty) {
        throw SynheartWearError(
          'No wearable data available. Please check if your wearable device is connected and syncing data.',
          code: 'NO_WEARABLE_DATA',
        );
      }

      // Check if data is stale (older than 24 hours)
      final dataAge = DateTime.now().difference(mergedTestData.timestamp);
      const maxStaleAge = Duration(
        hours: 24,
      ); // Stricter threshold for initialization

      // Handle timezone differences (data timestamp might be slightly in the future)
      final isFutureData = dataAge.isNegative;
      final absoluteAge = isFutureData ? -dataAge : dataAge;

      if (isFutureData) {
      } else {}

      if (absoluteAge > maxStaleAge) {
        throw SynheartWearError(
          'Latest data is stale (${absoluteAge.inHours} hours old). Please check if your wearable device is connected to get latest data.',
          code: 'STALE_DATA',
        );
      }

      _initialized = true;
    } catch (e) {
      if (e is SynheartWearError) rethrow;
      throw SynheartWearError('Failed to initialize SynheartWear: $e');
    }
  }

  /// Read current metrics from all enabled adapters
  Future<WearMetrics> readMetrics({
    bool isRealTime = false,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      // Validate consents
      ConsentManager.validateConsents(_getRequiredPermissions());

      // Gather data from enabled adapters
      final adapterData = <WearMetrics?>[];
      for (final adapter in _enabledAdapters()) {
        try {
          final data = await adapter.readSnapshot(
            isRealTime: isRealTime,
            startTime: startTime,
            endTime: endTime,
          );
          adapterData.add(data);
        } catch (e) {
          // Keep non-fatal, tag by adapter id
          logWarning('${adapter.id} adapter error', e);
        }
      }

      // Normalize and merge data
      final mergedData = _normalizer.mergeSnapshots(adapterData);

      // Validate data quality
      // Note: Data availability is validated during initialize(), but empty data
      // may still occur if device disconnects after initialization
      if (mergedData.metrics.isNotEmpty &&
          !_normalizer.validateMetrics(mergedData)) {
        throw SynheartWearError('Invalid metrics data received');
      }

      // If no data is available, return empty metrics
      // This may occur if device disconnected after initialization

      // Cache data if enabled
      if (config.enableLocalCaching) {
        await LocalCache.storeSession(
          mergedData,
          enableEncryption: config.enableEncryption,
        );
      }

      return mergedData;
    } catch (e) {
      if (e is SynheartWearError) rethrow;
      throw SynheartWearError('Failed to read metrics: $e');
    }
  }

  /// Stream real-time heart rate data
  Stream<WearMetrics> streamHR({Duration? interval}) {
    final actualInterval = interval ?? config.streamInterval;

    _hrStreamController ??= StreamController<WearMetrics>.broadcast();

    // Start timer when first listener subscribes
    if (!_hrStreamController!.hasListener) {
      _startStreaming(actualInterval);
    }

    return _hrStreamController!.stream;
  }

  /// Stream HRV data in configurable windows (RFC specification)
  Stream<WearMetrics> streamHRV({Duration? windowSize}) {
    final actualWindowSize = windowSize ?? config.hrvWindowSize;

    _hrvStreamController ??= StreamController<WearMetrics>.broadcast();

    // Start timer when first listener subscribes
    if (!_hrvStreamController!.hasListener) {
      _startHrvStreaming(actualWindowSize);
    }

    return _hrvStreamController!.stream;
  }

  /// Read a Flux HSI snapshot for the specified time window
  ///
  /// Returns an HSI-compliant payload containing derived signals from wearable
  /// data within the specified window.
  ///
  /// [windowMs] - Time window in milliseconds to aggregate data (default: 60000ms / 1 minute)
  /// [vendor] - Source vendor for the data (required for HSI provenance)
  /// [deviceId] - Device identifier for provenance tracking
  /// [timezone] - User's timezone (e.g., "America/New_York")
  /// [rawVendorJson] - Raw vendor JSON payload to process (if available)
  ///
  /// Throws [SynheartWearError] if Flux is not enabled in config.
  ///
  /// Example:
  /// ```dart
  /// final wear = SynheartWear(config: SynheartWearConfig(enableFlux: true));
  /// final snapshot = await wear.readFluxSnapshot(
  ///   windowMs: 60000,
  ///   vendor: Vendor.whoop,
  ///   deviceId: 'device-123',
  ///   timezone: 'America/New_York',
  ///   rawVendorJson: whoopApiResponse,
  /// );
  /// ```
  Future<HsiPayload> readFluxSnapshot({
    int windowMs = 60000,
    required Vendor vendor,
    required String deviceId,
    required String timezone,
    required String rawVendorJson,
  }) async {
    if (!config.enableFlux) {
      throw SynheartWearError(
        'Flux is not enabled. Set enableFlux: true in SynheartWearConfig.',
        code: 'FLUX_DISABLED',
      );
    }

    if (!_initialized) {
      await initialize();
    }

    // Lazy initialize the Flux processor
    _fluxProcessor ??= FluxProcessor();

    try {
      final List<HsiPayload> payloads;

      switch (vendor) {
        case Vendor.whoop:
          final jsonStrings = _fluxProcessor!.processWhoop(
            rawVendorJson,
            timezone,
            deviceId,
          );
          payloads = _parseHsiPayloads(jsonStrings);
        case Vendor.garmin:
          final jsonStrings = _fluxProcessor!.processGarmin(
            rawVendorJson,
            timezone,
            deviceId,
          );
          payloads = _parseHsiPayloads(jsonStrings);
      }

      if (payloads.isEmpty) {
        throw SynheartWearError(
          'No Flux data available for the specified window.',
          code: 'NO_FLUX_DATA',
        );
      }

      // Return the most recent payload
      return payloads.last;
    } catch (e) {
      if (e is SynheartWearError) rethrow;
      throw SynheartWearError('Failed to read Flux snapshot: $e');
    }
  }

  /// Stream Flux HSI snapshots at regular intervals
  ///
  /// Returns a stream of HSI-compliant payloads at the specified interval.
  ///
  /// [windowMs] - Time window in milliseconds for each snapshot (default: 60000ms)
  /// [interval] - How often to emit snapshots (default: 60 seconds)
  /// [vendor] - Source vendor for the data
  /// [deviceId] - Device identifier for provenance tracking
  /// [timezone] - User's timezone
  /// [fetchVendorData] - Callback to fetch fresh vendor JSON data for each snapshot
  ///
  /// Throws [SynheartWearError] if Flux is not enabled in config.
  ///
  /// Example:
  /// ```dart
  /// final stream = wear.streamFluxSnapshots(
  ///   windowMs: 60000,
  ///   interval: Duration(minutes: 1),
  ///   vendor: Vendor.whoop,
  ///   deviceId: 'device-123',
  ///   timezone: 'America/New_York',
  ///   fetchVendorData: () async => await whoopApi.fetchLatest(),
  /// );
  ///
  /// await for (final snapshot in stream) {
  ///   print('HRV: ${snapshot.windows.first.physiology.hrvRmssdMs}');
  /// }
  /// ```
  Stream<HsiPayload> streamFluxSnapshots({
    int windowMs = 60000,
    Duration interval = const Duration(seconds: 60),
    required Vendor vendor,
    required String deviceId,
    required String timezone,
    required Future<String> Function() fetchVendorData,
  }) {
    if (!config.enableFlux) {
      throw SynheartWearError(
        'Flux is not enabled. Set enableFlux: true in SynheartWearConfig.',
        code: 'FLUX_DISABLED',
      );
    }

    _fluxStreamController ??= StreamController<HsiPayload>.broadcast();

    // Start timer when first listener subscribes
    if (!_fluxStreamController!.hasListener) {
      _startFluxStreaming(
        windowMs: windowMs,
        interval: interval,
        vendor: vendor,
        deviceId: deviceId,
        timezone: timezone,
        fetchVendorData: fetchVendorData,
      );
    }

    return _fluxStreamController!.stream;
  }

  /// Get the current Flux baselines (for persistence)
  ///
  /// Returns JSON string of baseline state that can be saved and restored.
  /// Useful for maintaining baseline continuity across app restarts.
  ///
  /// Throws [SynheartWearError] if Flux is not enabled or not initialized.
  String saveFluxBaselines() {
    if (!config.enableFlux) {
      throw SynheartWearError(
        'Flux is not enabled. Set enableFlux: true in SynheartWearConfig.',
        code: 'FLUX_DISABLED',
      );
    }

    if (_fluxProcessor == null) {
      throw SynheartWearError(
        'Flux processor not initialized. Call readFluxSnapshot first.',
        code: 'FLUX_NOT_INITIALIZED',
      );
    }

    return _fluxProcessor!.saveBaselines();
  }

  /// Load previously saved Flux baselines
  ///
  /// [baselinesJson] - JSON string from saveFluxBaselines()
  ///
  /// Throws [SynheartWearError] if Flux is not enabled.
  void loadFluxBaselines(String baselinesJson) {
    if (!config.enableFlux) {
      throw SynheartWearError(
        'Flux is not enabled. Set enableFlux: true in SynheartWearConfig.',
        code: 'FLUX_DISABLED',
      );
    }

    _fluxProcessor ??= FluxProcessor();
    _fluxProcessor!.loadBaselines(baselinesJson);
  }

  /// Get cached sessions for analysis
  Future<List<WearMetrics>> getCachedSessions({
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    if (!config.enableLocalCaching) {
      throw SynheartWearError('Local caching is disabled');
    }

    return await LocalCache.getCachedSessions(
      startDate: startDate,
      endDate: endDate,
      limit: limit,
    );
  }

  /// Get cache statistics
  Future<Map<String, Object?>> getCacheStats() async {
    if (!config.enableLocalCaching) {
      return {'enabled': false, 'encryption_enabled': false};
    }

    return await LocalCache.getCacheStats(
      encryptionEnabled: config.enableEncryption,
    );
  }

  /// Clear old cached data
  Future<void> clearOldCache({
    Duration maxAge = const Duration(days: 30),
  }) async {
    if (!config.enableLocalCaching) return;

    await LocalCache.clearOldData(maxAge: maxAge);
  }

  /// Request permissions for data access
  Future<Map<PermissionType, ConsentStatus>> requestPermissions({
    Set<PermissionType>? permissions,
    String? reason,
  }) async {
    final requiredPermissions = permissions ?? _getRequiredPermissions();
    return await ConsentManager.requestConsent(
      requiredPermissions,
      reason: reason,
    );
  }

  /// Check current permission status
  Map<PermissionType, ConsentStatus> getPermissionStatus() {
    return ConsentManager.getAllConsents();
  }

  /// Revoke all permissions
  Future<void> revokeAllPermissions() async {
    await ConsentManager.revokeAllConsents();
  }

  /// Dispose resources
  void dispose() {
    _streamTimer?.cancel();
    _hrvTimer?.cancel();
    _fluxTimer?.cancel();
    _hrStreamController?.close();
    _hrvStreamController?.close();
    _fluxStreamController?.close();
    _fluxProcessor = null;
    _initialized = false;
  }

  /// Request necessary permissions based on enabled adapters
  Future<void> _requestPermissions() async {
    final requiredPermissions = _getRequiredPermissions();
    await ConsentManager.requestConsent(requiredPermissions);
  }

  /// Get required permissions based on enabled adapters
  /// Uses platform-specific permissions (e.g., excludes HRV on Android)
  Set<PermissionType> _getRequiredPermissions() {
    final permissions = <PermissionType>{};
    for (final adapter in _enabledAdapters()) {
      // Use platform-specific permissions instead of all supported permissions
      permissions.addAll(adapter.getPlatformSupportedPermissions());
    }
    return permissions;
  }

  // Helper to get enabled adapter instances
  List<WearAdapter> _enabledAdapters() {
    return config.enabledAdapters
        .where(_adapterRegistry.containsKey)
        .map((d) => _adapterRegistry[d]!)
        .toList();
  }

  /// Initialize enabled adapters
  Future<void> _initializeAdapters() async {
    for (final adapter in _enabledAdapters()) {
      await adapter.ensurePermissions();
    }
  }

  /// Start the streaming timer
  void _startStreaming(Duration interval) {
    _streamTimer?.cancel();
    _streamTimer = Timer.periodic(interval, (timer) async {
      // Check if we still have subscribers
      if (_hrStreamController?.hasListener != true) {
        _streamTimer?.cancel();
        _streamTimer = null;
        return;
      }

      try {
        final metrics = await readMetrics(isRealTime: true);
        _hrStreamController?.add(metrics);
      } catch (e) {
        _hrStreamController?.addError(e);
      }
    });
  }

  /// Start HRV streaming timer
  void _startHrvStreaming(Duration windowSize) {
    _hrvTimer?.cancel();
    _hrvTimer = Timer.periodic(windowSize, (timer) async {
      // Check if we still have subscribers
      if (_hrvStreamController?.hasListener != true) {
        _hrvTimer?.cancel();
        _hrvTimer = null;
        return;
      }

      try {
        final metrics = await readMetrics(isRealTime: true);
        // Check for either HRV metric type (SDNN or RMSSD)
        final hrvSdnn = metrics.getMetric(MetricType.hrvSdnn);
        final hrvRmssd = metrics.getMetric(MetricType.hrvRmssd);

        // Emit metrics if any HRV data is present
        if (hrvSdnn != null || hrvRmssd != null) {
          _hrvStreamController?.add(metrics);
        }
      } catch (e) {
        _hrvStreamController?.addError(e);
      }
    });
  }

  /// Start Flux streaming timer
  void _startFluxStreaming({
    required int windowMs,
    required Duration interval,
    required Vendor vendor,
    required String deviceId,
    required String timezone,
    required Future<String> Function() fetchVendorData,
  }) {
    _fluxTimer?.cancel();
    _fluxTimer = Timer.periodic(interval, (timer) async {
      // Check if we still have subscribers
      if (_fluxStreamController?.hasListener != true) {
        _fluxTimer?.cancel();
        _fluxTimer = null;
        return;
      }

      try {
        final rawJson = await fetchVendorData();
        final snapshot = await readFluxSnapshot(
          windowMs: windowMs,
          vendor: vendor,
          deviceId: deviceId,
          timezone: timezone,
          rawVendorJson: rawJson,
        );
        _fluxStreamController?.add(snapshot);
      } catch (e) {
        _fluxStreamController?.addError(e);
      }
    });
  }

  /// Parse HSI JSON strings into HsiPayload objects
  List<HsiPayload> _parseHsiPayloads(List<String> jsonStrings) {
    return jsonStrings.map((jsonStr) {
      final json = _decodeJson(jsonStr);
      return _hsiPayloadFromJson(json);
    }).toList();
  }

  /// Decode JSON string to Map
  Map<String, dynamic> _decodeJson(String jsonStr) {
    // Using dart:convert would require an import, so we use a simple approach
    // In production, this would use json.decode
    return Map<String, dynamic>.from(
      (const JsonDecoder()).convert(jsonStr) as Map,
    );
  }

  /// Convert JSON map to HsiPayload
  HsiPayload _hsiPayloadFromJson(Map<String, dynamic> json) {
    final producerJson = json['producer'] as Map<String, dynamic>;
    final provenanceJson = json['provenance'] as Map<String, dynamic>;
    final qualityJson = json['quality'] as Map<String, dynamic>;
    final windowsJson = json['windows'] as List<dynamic>;

    return HsiPayload(
      hsiVersion: json['hsi_version'] as String,
      producer: HsiProducer(
        name: producerJson['name'] as String,
        version: producerJson['version'] as String,
        instanceId: producerJson['instance_id'] as String,
      ),
      provenance: HsiProvenance(
        sourceVendor: provenanceJson['source_vendor'] as String,
        sourceDeviceId: provenanceJson['source_device_id'] as String,
        observedAtUtc: provenanceJson['observed_at_utc'] as String,
        computedAtUtc: provenanceJson['computed_at_utc'] as String,
      ),
      quality: HsiQuality(
        coverage: (qualityJson['coverage'] as num).toDouble(),
        freshnessSec: qualityJson['freshness_sec'] as int,
        confidence: (qualityJson['confidence'] as num).toDouble(),
        flags: List<String>.from(qualityJson['flags'] as List? ?? []),
      ),
      windows: windowsJson.map((w) => _hsiDailyWindowFromJson(w as Map<String, dynamic>)).toList(),
    );
  }

  /// Convert JSON map to HsiDailyWindow
  HsiDailyWindow _hsiDailyWindowFromJson(Map<String, dynamic> json) {
    final sleepJson = json['sleep'] as Map<String, dynamic>;
    final physiologyJson = json['physiology'] as Map<String, dynamic>;
    final activityJson = json['activity'] as Map<String, dynamic>;
    final baselineJson = json['baseline'] as Map<String, dynamic>;

    return HsiDailyWindow(
      date: json['date'] as String,
      timezone: json['timezone'] as String,
      sleep: HsiSleep(
        durationMinutes: (sleepJson['duration_minutes'] as num?)?.toDouble(),
        efficiency: (sleepJson['efficiency'] as num?)?.toDouble(),
        fragmentation: (sleepJson['fragmentation'] as num?)?.toDouble(),
        deepRatio: (sleepJson['deep_ratio'] as num?)?.toDouble(),
        remRatio: (sleepJson['rem_ratio'] as num?)?.toDouble(),
        latencyMinutes: (sleepJson['latency_minutes'] as num?)?.toDouble(),
        score: (sleepJson['score'] as num?)?.toDouble(),
        vendor: Map<String, dynamic>.from(sleepJson['vendor'] as Map? ?? {}),
      ),
      physiology: HsiPhysiology(
        hrvRmssdMs: (physiologyJson['hrv_rmssd_ms'] as num?)?.toDouble(),
        restingHrBpm: (physiologyJson['resting_hr_bpm'] as num?)?.toDouble(),
        respiratoryRate: (physiologyJson['respiratory_rate'] as num?)?.toDouble(),
        spo2Percentage: (physiologyJson['spo2_percentage'] as num?)?.toDouble(),
        recoveryScore: (physiologyJson['recovery_score'] as num?)?.toDouble(),
        vendor: Map<String, dynamic>.from(physiologyJson['vendor'] as Map? ?? {}),
      ),
      activity: HsiActivity(
        strainScore: (activityJson['strain_score'] as num?)?.toDouble(),
        normalizedLoad: (activityJson['normalized_load'] as num?)?.toDouble(),
        calories: (activityJson['calories'] as num?)?.toDouble(),
        activeCalories: (activityJson['active_calories'] as num?)?.toDouble(),
        steps: activityJson['steps'] as int?,
        activeMinutes: (activityJson['active_minutes'] as num?)?.toDouble(),
        distanceMeters: (activityJson['distance_meters'] as num?)?.toDouble(),
        vendor: Map<String, dynamic>.from(activityJson['vendor'] as Map? ?? {}),
      ),
      baseline: HsiBaseline(
        hrvMs: (baselineJson['hrv_ms'] as num?)?.toDouble(),
        restingHrBpm: (baselineJson['resting_hr_bpm'] as num?)?.toDouble(),
        sleepDurationMinutes: (baselineJson['sleep_duration_minutes'] as num?)?.toDouble(),
        sleepEfficiency: (baselineJson['sleep_efficiency'] as num?)?.toDouble(),
        hrvDeviationPct: (baselineJson['hrv_deviation_pct'] as num?)?.toDouble(),
        rhrDeviationPct: (baselineJson['rhr_deviation_pct'] as num?)?.toDouble(),
        sleepDeviationPct: (baselineJson['sleep_deviation_pct'] as num?)?.toDouble(),
        daysInBaseline: baselineJson['days_in_baseline'] as int? ?? 0,
      ),
    );
  }

  /// Getter for testing timer state
  @visibleForTesting
  bool get isStreamTimerActive => _streamTimer?.isActive ?? false;

  @visibleForTesting
  bool get isHrvTimerActive => _hrvTimer?.isActive ?? false;

  @visibleForTesting
  bool get isFluxTimerActive => _fluxTimer?.isActive ?? false;
}
