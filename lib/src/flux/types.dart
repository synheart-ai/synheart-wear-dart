/// Core types for the Synheart Flux pipeline
///
/// This module defines the data structures that flow through each stage of the
/// pipeline: canonical signals, normalized signals, derived signals, and HSI output.

/// Vendor identifier for provenance tracking
enum Vendor {
  whoop,
  garmin;

  String get value {
    switch (this) {
      case Vendor.whoop:
        return 'whoop';
      case Vendor.garmin:
        return 'garmin';
    }
  }
}

/// Sleep stage classification (vendor-agnostic)
enum SleepStage { awake, light, deep, rem, unknown }

/// Quality flag indicating data issues
enum QualityFlag {
  missingSleepData,
  missingRecoveryData,
  missingActivityData,
  missingHrv,
  missingRestingHr,
  estimatedValue,
  partialDayData,
  lowConfidence;

  String get value => name.toLowerCase();
}

/// Canonical sleep data extracted from vendor payloads
class CanonicalSleep {
  /// Sleep start time (UTC)
  final DateTime? startTime;

  /// Sleep end time (UTC)
  final DateTime? endTime;

  /// Total time in bed (minutes)
  final double? timeInBedMinutes;

  /// Total sleep duration (minutes)
  final double? totalSleepMinutes;

  /// Time awake during sleep period (minutes)
  final double? awakeMinutes;

  /// Light sleep duration (minutes)
  final double? lightSleepMinutes;

  /// Deep sleep duration (minutes)
  final double? deepSleepMinutes;

  /// REM sleep duration (minutes)
  final double? remSleepMinutes;

  /// Number of awakenings
  final int? awakenings;

  /// Sleep latency - time to fall asleep (minutes)
  final double? latencyMinutes;

  /// Vendor-provided sleep score (raw, vendor-specific scale)
  final double? vendorSleepScore;

  /// Respiratory rate during sleep (breaths per minute)
  final double? respiratoryRate;

  const CanonicalSleep({
    this.startTime,
    this.endTime,
    this.timeInBedMinutes,
    this.totalSleepMinutes,
    this.awakeMinutes,
    this.lightSleepMinutes,
    this.deepSleepMinutes,
    this.remSleepMinutes,
    this.awakenings,
    this.latencyMinutes,
    this.vendorSleepScore,
    this.respiratoryRate,
  });

  Map<String, dynamic> toJson() => {
    if (startTime != null) 'start_time': startTime!.toIso8601String(),
    if (endTime != null) 'end_time': endTime!.toIso8601String(),
    if (timeInBedMinutes != null) 'time_in_bed_minutes': timeInBedMinutes,
    if (totalSleepMinutes != null) 'total_sleep_minutes': totalSleepMinutes,
    if (awakeMinutes != null) 'awake_minutes': awakeMinutes,
    if (lightSleepMinutes != null) 'light_sleep_minutes': lightSleepMinutes,
    if (deepSleepMinutes != null) 'deep_sleep_minutes': deepSleepMinutes,
    if (remSleepMinutes != null) 'rem_sleep_minutes': remSleepMinutes,
    if (awakenings != null) 'awakenings': awakenings,
    if (latencyMinutes != null) 'latency_minutes': latencyMinutes,
    if (vendorSleepScore != null) 'vendor_sleep_score': vendorSleepScore,
    if (respiratoryRate != null) 'respiratory_rate': respiratoryRate,
  };
}

/// Canonical recovery/physiology data extracted from vendor payloads
class CanonicalRecovery {
  /// Heart rate variability (ms, RMSSD)
  final double? hrvRmssdMs;

  /// Resting heart rate (bpm)
  final double? restingHrBpm;

  /// Vendor-provided recovery score (raw, vendor-specific scale)
  final double? vendorRecoveryScore;

  /// Skin temperature deviation (celsius)
  final double? skinTempDeviationC;

  /// Blood oxygen saturation (percentage, 0-100)
  final double? spo2Percentage;

  const CanonicalRecovery({
    this.hrvRmssdMs,
    this.restingHrBpm,
    this.vendorRecoveryScore,
    this.skinTempDeviationC,
    this.spo2Percentage,
  });

  Map<String, dynamic> toJson() => {
    if (hrvRmssdMs != null) 'hrv_rmssd_ms': hrvRmssdMs,
    if (restingHrBpm != null) 'resting_hr_bpm': restingHrBpm,
    if (vendorRecoveryScore != null)
      'vendor_recovery_score': vendorRecoveryScore,
    if (skinTempDeviationC != null) 'skin_temp_deviation_c': skinTempDeviationC,
    if (spo2Percentage != null) 'spo2_percentage': spo2Percentage,
  };
}

/// Canonical activity/strain data extracted from vendor payloads
class CanonicalActivity {
  /// Vendor-provided strain/load score (raw, vendor-specific scale)
  final double? vendorStrainScore;

  /// Total calories burned
  final double? calories;

  /// Active calories burned
  final double? activeCalories;

  /// Average heart rate during activity (bpm)
  final double? averageHrBpm;

  /// Maximum heart rate during activity (bpm)
  final double? maxHrBpm;

  /// Total distance (meters)
  final double? distanceMeters;

  /// Number of steps
  final int? steps;

  /// Active duration (minutes)
  final double? activeMinutes;

  const CanonicalActivity({
    this.vendorStrainScore,
    this.calories,
    this.activeCalories,
    this.averageHrBpm,
    this.maxHrBpm,
    this.distanceMeters,
    this.steps,
    this.activeMinutes,
  });

  Map<String, dynamic> toJson() => {
    if (vendorStrainScore != null) 'vendor_strain_score': vendorStrainScore,
    if (calories != null) 'calories': calories,
    if (activeCalories != null) 'active_calories': activeCalories,
    if (averageHrBpm != null) 'average_hr_bpm': averageHrBpm,
    if (maxHrBpm != null) 'max_hr_bpm': maxHrBpm,
    if (distanceMeters != null) 'distance_meters': distanceMeters,
    if (steps != null) 'steps': steps,
    if (activeMinutes != null) 'active_minutes': activeMinutes,
  };
}

/// Canonical wear signals - vendor-agnostic representation of wearable data
class CanonicalWearSignals {
  /// Source vendor
  final Vendor vendor;

  /// Date this data represents (YYYY-MM-DD)
  final String date;

  /// Device identifier
  final String deviceId;

  /// Timezone of the user
  final String timezone;

  /// When the data was observed/recorded by the vendor
  final DateTime observedAt;

  /// Sleep data
  final CanonicalSleep sleep;

  /// Recovery/physiology data
  final CanonicalRecovery recovery;

  /// Activity/strain data
  final CanonicalActivity activity;

  /// Raw vendor-specific metrics preserved for transparency
  final Map<String, dynamic> vendorRaw;

  const CanonicalWearSignals({
    required this.vendor,
    required this.date,
    required this.deviceId,
    required this.timezone,
    required this.observedAt,
    this.sleep = const CanonicalSleep(),
    this.recovery = const CanonicalRecovery(),
    this.activity = const CanonicalActivity(),
    this.vendorRaw = const {},
  });

  Map<String, dynamic> toJson() => {
    'vendor': vendor.value,
    'date': date,
    'device_id': deviceId,
    'timezone': timezone,
    'observed_at': observedAt.toIso8601String(),
    'sleep': sleep.toJson(),
    'recovery': recovery.toJson(),
    'activity': activity.toJson(),
    'vendor_raw': vendorRaw,
  };
}

/// Normalized signals with consistent units and scales
class NormalizedSignals {
  /// Source canonical signals
  final CanonicalWearSignals canonical;

  /// Normalized sleep score (0-1)
  final double? sleepScore;

  /// Normalized recovery score (0-1)
  final double? recoveryScore;

  /// Normalized strain/load score (0-1)
  final double? strainScore;

  /// Data completeness (0-1)
  final double coverage;

  /// Flags for missing or estimated data
  final List<QualityFlag> qualityFlags;

  const NormalizedSignals({
    required this.canonical,
    this.sleepScore,
    this.recoveryScore,
    this.strainScore,
    required this.coverage,
    this.qualityFlags = const [],
  });
}

/// Derived features computed from normalized signals
class DerivedSignals {
  /// Source normalized signals
  final NormalizedSignals normalized;

  /// Sleep efficiency (actual sleep / time in bed, 0-1)
  final double? sleepEfficiency;

  /// Sleep fragmentation index (0-1, higher = more fragmented)
  final double? sleepFragmentation;

  /// Deep sleep ratio (deep sleep / total sleep, 0-1)
  final double? deepSleepRatio;

  /// REM sleep ratio (REM / total sleep, 0-1)
  final double? remSleepRatio;

  /// Normalized load (strain adjusted by recovery)
  final double? normalizedLoad;

  const DerivedSignals({
    required this.normalized,
    this.sleepEfficiency,
    this.sleepFragmentation,
    this.deepSleepRatio,
    this.remSleepRatio,
    this.normalizedLoad,
  });
}

/// Baseline values for relative interpretation
class Baselines {
  /// Baseline HRV (rolling average, ms)
  final double? hrvBaselineMs;

  /// Baseline resting HR (rolling average, bpm)
  final double? rhrBaselineBpm;

  /// Baseline sleep duration (rolling average, minutes)
  final double? sleepBaselineMinutes;

  /// Baseline sleep efficiency (rolling average, 0-1)
  final double? sleepEfficiencyBaseline;

  /// Number of days used to compute baselines
  final int baselineDays;

  const Baselines({
    this.hrvBaselineMs,
    this.rhrBaselineBpm,
    this.sleepBaselineMinutes,
    this.sleepEfficiencyBaseline,
    this.baselineDays = 0,
  });

  Map<String, dynamic> toJson() => {
    if (hrvBaselineMs != null) 'hrv_baseline_ms': hrvBaselineMs,
    if (rhrBaselineBpm != null) 'rhr_baseline_bpm': rhrBaselineBpm,
    if (sleepBaselineMinutes != null)
      'sleep_baseline_minutes': sleepBaselineMinutes,
    if (sleepEfficiencyBaseline != null)
      'sleep_efficiency_baseline': sleepEfficiencyBaseline,
    'baseline_days': baselineDays,
  };

  factory Baselines.fromJson(Map<String, dynamic> json) => Baselines(
    hrvBaselineMs: (json['hrv_baseline_ms'] as num?)?.toDouble(),
    rhrBaselineBpm: (json['rhr_baseline_bpm'] as num?)?.toDouble(),
    sleepBaselineMinutes: (json['sleep_baseline_minutes'] as num?)?.toDouble(),
    sleepEfficiencyBaseline: (json['sleep_efficiency_baseline'] as num?)
        ?.toDouble(),
    baselineDays: json['baseline_days'] as int? ?? 0,
  );
}

/// Contextual signals with baseline comparisons
class ContextualSignals {
  /// Source derived signals
  final DerivedSignals derived;

  /// Current baselines
  final Baselines baselines;

  /// HRV deviation from baseline (percentage)
  final double? hrvDeviationPct;

  /// RHR deviation from baseline (percentage)
  final double? rhrDeviationPct;

  /// Sleep duration deviation from baseline (percentage)
  final double? sleepDurationDeviationPct;

  const ContextualSignals({
    required this.derived,
    required this.baselines,
    this.hrvDeviationPct,
    this.rhrDeviationPct,
    this.sleepDurationDeviationPct,
  });
}

/// HSI 1.0 producer metadata
class HsiProducer {
  final String name;
  final String version;
  final String instanceId;

  const HsiProducer({
    required this.name,
    required this.version,
    required this.instanceId,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'version': version,
    'instance_id': instanceId,
  };

  factory HsiProducer.fromJson(Map<String, dynamic> json) => HsiProducer(
    name: json['name'] as String? ?? 'synheart-flux',
    version: json['version'] as String? ?? '0.1.1',
    instanceId: json['instance_id'] as String? ?? '',
  );
}

/// HSI 1.0 time window
class HsiWindow {
  final String start;
  final String end;
  final String? label;

  const HsiWindow({required this.start, required this.end, this.label});

  Map<String, dynamic> toJson() => {
    'start': start,
    'end': end,
    if (label != null) 'label': label,
  };

  factory HsiWindow.fromJson(Map<String, dynamic> json) => HsiWindow(
    start: json['start'] as String? ?? '',
    end: json['end'] as String? ?? '',
    label: json['label'] as String?,
  );
}

/// HSI 1.0 source type
enum HsiSourceType {
  sensor,
  app,
  selfReport,
  observer,
  derived,
  other;

  String get value {
    switch (this) {
      case HsiSourceType.sensor:
        return 'sensor';
      case HsiSourceType.app:
        return 'app';
      case HsiSourceType.selfReport:
        return 'self_report';
      case HsiSourceType.observer:
        return 'observer';
      case HsiSourceType.derived:
        return 'derived';
      case HsiSourceType.other:
        return 'other';
    }
  }

  static HsiSourceType fromString(String s) {
    switch (s) {
      case 'sensor':
        return HsiSourceType.sensor;
      case 'app':
        return HsiSourceType.app;
      case 'self_report':
        return HsiSourceType.selfReport;
      case 'observer':
        return HsiSourceType.observer;
      case 'derived':
        return HsiSourceType.derived;
      default:
        return HsiSourceType.other;
    }
  }
}

/// HSI 1.0 data source
class HsiSource {
  final HsiSourceType type;
  final double quality;
  final bool degraded;
  final String? notes;

  const HsiSource({
    required this.type,
    required this.quality,
    this.degraded = false,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'type': type.value,
    'quality': quality,
    'degraded': degraded,
    if (notes != null) 'notes': notes,
  };

  factory HsiSource.fromJson(Map<String, dynamic> json) => HsiSource(
    type: HsiSourceType.fromString(json['type'] as String? ?? 'sensor'),
    quality: (json['quality'] as num?)?.toDouble() ?? 0.0,
    degraded: json['degraded'] as bool? ?? false,
    notes: json['notes'] as String?,
  );
}

/// HSI 1.0 axis direction
enum HsiDirection {
  higherIsMore,
  higherIsLess,
  bidirectional;

  String get value {
    switch (this) {
      case HsiDirection.higherIsMore:
        return 'higher_is_more';
      case HsiDirection.higherIsLess:
        return 'higher_is_less';
      case HsiDirection.bidirectional:
        return 'bidirectional';
    }
  }

  static HsiDirection fromString(String s) {
    switch (s) {
      case 'higher_is_more':
        return HsiDirection.higherIsMore;
      case 'higher_is_less':
        return HsiDirection.higherIsLess;
      case 'bidirectional':
        return HsiDirection.bidirectional;
      default:
        return HsiDirection.higherIsMore;
    }
  }
}

/// HSI 1.0 axis reading
class HsiAxisReading {
  final String axis;
  final double score;
  final double confidence;
  final String windowId;
  final HsiDirection direction;
  final String? unit;
  final List<String> evidenceSourceIds;
  final String? notes;

  const HsiAxisReading({
    required this.axis,
    required this.score,
    required this.confidence,
    required this.windowId,
    required this.direction,
    this.unit,
    this.evidenceSourceIds = const [],
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'axis': axis,
    'score': score,
    'confidence': confidence,
    'window_id': windowId,
    'direction': direction.value,
    if (unit != null) 'unit': unit,
    'evidence_source_ids': evidenceSourceIds,
    if (notes != null) 'notes': notes,
  };

  factory HsiAxisReading.fromJson(Map<String, dynamic> json) => HsiAxisReading(
    axis: json['axis'] as String? ?? '',
    score: (json['score'] as num?)?.toDouble() ?? 0.0,
    confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
    windowId: json['window_id'] as String? ?? '',
    direction: HsiDirection.fromString(
      json['direction'] as String? ?? 'higher_is_more',
    ),
    unit: json['unit'] as String?,
    evidenceSourceIds:
        (json['evidence_source_ids'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [],
    notes: json['notes'] as String?,
  );
}

/// HSI 1.0 axes domain (e.g., behavior, affect, engagement)
class HsiAxesDomain {
  final List<HsiAxisReading> readings;

  const HsiAxesDomain({this.readings = const []});

  Map<String, dynamic> toJson() => {
    'readings': readings.map((r) => r.toJson()).toList(),
  };

  factory HsiAxesDomain.fromJson(Map<String, dynamic> json) => HsiAxesDomain(
    readings:
        (json['readings'] as List<dynamic>?)
            ?.map((e) => HsiAxisReading.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
  );
}

/// HSI 1.0 axes container
class HsiAxes {
  final HsiAxesDomain? affect;
  final HsiAxesDomain? engagement;
  final HsiAxesDomain? behavior;

  const HsiAxes({this.affect, this.engagement, this.behavior});

  Map<String, dynamic> toJson() => {
    if (affect != null) 'affect': affect!.toJson(),
    if (engagement != null) 'engagement': engagement!.toJson(),
    if (behavior != null) 'behavior': behavior!.toJson(),
  };

  factory HsiAxes.fromJson(Map<String, dynamic> json) => HsiAxes(
    affect: json['affect'] != null
        ? HsiAxesDomain.fromJson(json['affect'] as Map<String, dynamic>)
        : null,
    engagement: json['engagement'] != null
        ? HsiAxesDomain.fromJson(json['engagement'] as Map<String, dynamic>)
        : null,
    behavior: json['behavior'] != null
        ? HsiAxesDomain.fromJson(json['behavior'] as Map<String, dynamic>)
        : null,
  );
}

/// HSI 1.0 privacy declarations
class HsiPrivacy {
  final bool containsPii;
  final bool rawBiosignalsAllowed;
  final bool derivedMetricsAllowed;
  final List<String> purposes;
  final String? notes;

  const HsiPrivacy({
    this.containsPii = false,
    this.rawBiosignalsAllowed = false,
    this.derivedMetricsAllowed = true,
    this.purposes = const [],
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'contains_pii': containsPii,
    'raw_biosignals_allowed': rawBiosignalsAllowed,
    'derived_metrics_allowed': derivedMetricsAllowed,
    if (purposes.isNotEmpty) 'purposes': purposes,
    if (notes != null) 'notes': notes,
  };

  factory HsiPrivacy.fromJson(Map<String, dynamic> json) => HsiPrivacy(
    containsPii: json['contains_pii'] as bool? ?? false,
    rawBiosignalsAllowed: json['raw_biosignals_allowed'] as bool? ?? false,
    derivedMetricsAllowed: json['derived_metrics_allowed'] as bool? ?? true,
    purposes:
        (json['purposes'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        [],
    notes: json['notes'] as String?,
  );
}

/// HSI sleep namespace signals
class HsiSleep {
  final double? durationMinutes;
  final double? efficiency;
  final double? fragmentation;
  final double? deepRatio;
  final double? remRatio;
  final double? latencyMinutes;
  final double? score;
  final Map<String, dynamic> vendor;

  const HsiSleep({
    this.durationMinutes,
    this.efficiency,
    this.fragmentation,
    this.deepRatio,
    this.remRatio,
    this.latencyMinutes,
    this.score,
    this.vendor = const {},
  });

  Map<String, dynamic> toJson() => {
    if (durationMinutes != null) 'duration_minutes': durationMinutes,
    if (efficiency != null) 'efficiency': efficiency,
    if (fragmentation != null) 'fragmentation': fragmentation,
    if (deepRatio != null) 'deep_ratio': deepRatio,
    if (remRatio != null) 'rem_ratio': remRatio,
    if (latencyMinutes != null) 'latency_minutes': latencyMinutes,
    if (score != null) 'score': score,
    'vendor': vendor,
  };
}

/// HSI physiology namespace signals
class HsiPhysiology {
  final double? hrvRmssdMs;
  final double? restingHrBpm;
  final double? respiratoryRate;
  final double? spo2Percentage;
  final double? recoveryScore;
  final Map<String, dynamic> vendor;

  const HsiPhysiology({
    this.hrvRmssdMs,
    this.restingHrBpm,
    this.respiratoryRate,
    this.spo2Percentage,
    this.recoveryScore,
    this.vendor = const {},
  });

  Map<String, dynamic> toJson() => {
    if (hrvRmssdMs != null) 'hrv_rmssd_ms': hrvRmssdMs,
    if (restingHrBpm != null) 'resting_hr_bpm': restingHrBpm,
    if (respiratoryRate != null) 'respiratory_rate': respiratoryRate,
    if (spo2Percentage != null) 'spo2_percentage': spo2Percentage,
    if (recoveryScore != null) 'recovery_score': recoveryScore,
    'vendor': vendor,
  };
}

/// HSI activity namespace signals
class HsiActivity {
  final double? strainScore;
  final double? normalizedLoad;
  final double? calories;
  final double? activeCalories;
  final int? steps;
  final double? activeMinutes;
  final double? distanceMeters;
  final Map<String, dynamic> vendor;

  const HsiActivity({
    this.strainScore,
    this.normalizedLoad,
    this.calories,
    this.activeCalories,
    this.steps,
    this.activeMinutes,
    this.distanceMeters,
    this.vendor = const {},
  });

  Map<String, dynamic> toJson() => {
    if (strainScore != null) 'strain_score': strainScore,
    if (normalizedLoad != null) 'normalized_load': normalizedLoad,
    if (calories != null) 'calories': calories,
    if (activeCalories != null) 'active_calories': activeCalories,
    if (steps != null) 'steps': steps,
    if (activeMinutes != null) 'active_minutes': activeMinutes,
    if (distanceMeters != null) 'distance_meters': distanceMeters,
    'vendor': vendor,
  };
}

/// HSI baseline namespace signals
class HsiBaseline {
  final double? hrvMs;
  final double? restingHrBpm;
  final double? sleepDurationMinutes;
  final double? sleepEfficiency;
  final double? hrvDeviationPct;
  final double? rhrDeviationPct;
  final double? sleepDeviationPct;
  final int daysInBaseline;

  const HsiBaseline({
    this.hrvMs,
    this.restingHrBpm,
    this.sleepDurationMinutes,
    this.sleepEfficiency,
    this.hrvDeviationPct,
    this.rhrDeviationPct,
    this.sleepDeviationPct,
    this.daysInBaseline = 0,
  });

  Map<String, dynamic> toJson() => {
    if (hrvMs != null) 'hrv_ms': hrvMs,
    if (restingHrBpm != null) 'resting_hr_bpm': restingHrBpm,
    if (sleepDurationMinutes != null)
      'sleep_duration_minutes': sleepDurationMinutes,
    if (sleepEfficiency != null) 'sleep_efficiency': sleepEfficiency,
    if (hrvDeviationPct != null) 'hrv_deviation_pct': hrvDeviationPct,
    if (rhrDeviationPct != null) 'rhr_deviation_pct': rhrDeviationPct,
    if (sleepDeviationPct != null) 'sleep_deviation_pct': sleepDeviationPct,
    'days_in_baseline': daysInBaseline,
  };
}

/// HSI daily window (legacy, kept for backward compatibility)
/// @deprecated Use HsiWindow + HsiAxisReading for HSI 1.0 output
@Deprecated('Use HsiWindow + HsiAxisReading for HSI 1.0 output')
typedef HsiDailyWindow = LegacyHsiDailyWindow;

/// Complete HSI 1.0 payload
class HsiPayload {
  final String hsiVersion;
  final String observedAtUtc;
  final String computedAtUtc;
  final HsiProducer producer;
  final List<String> windowIds;
  final Map<String, HsiWindow> windows;
  final List<String> sourceIds;
  final Map<String, HsiSource> sources;
  final HsiAxes axes;
  final HsiPrivacy privacy;
  final Map<String, dynamic> meta;

  const HsiPayload({
    required this.hsiVersion,
    required this.observedAtUtc,
    required this.computedAtUtc,
    required this.producer,
    required this.windowIds,
    required this.windows,
    required this.sourceIds,
    required this.sources,
    required this.axes,
    required this.privacy,
    this.meta = const {},
  });

  Map<String, dynamic> toJson() => {
    'hsi_version': hsiVersion,
    'observed_at_utc': observedAtUtc,
    'computed_at_utc': computedAtUtc,
    'producer': producer.toJson(),
    'window_ids': windowIds,
    'windows': windows.map((k, v) => MapEntry(k, v.toJson())),
    'source_ids': sourceIds,
    'sources': sources.map((k, v) => MapEntry(k, v.toJson())),
    'axes': axes.toJson(),
    'privacy': privacy.toJson(),
    if (meta.isNotEmpty) 'meta': meta,
  };

  factory HsiPayload.fromJson(Map<String, dynamic> json) {
    // Helper to safely convert to Map, handling List cases
    Map<String, dynamic> safeMap(
      dynamic value, [
      Map<String, dynamic> defaultValue = const {},
    ]) {
      if (value == null) return defaultValue;
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
      if (value is List && value.isNotEmpty && value.first is Map) {
        // If it's a list of maps, take the first one
        final first = value.first;
        if (first is Map<String, dynamic>) return first;
        if (first is Map) return Map<String, dynamic>.from(first);
      }
      return defaultValue;
    }

    // Handle wearable format (has 'provenance' and 'windows' as array)
    // vs behavioral format (has 'observed_at_utc' directly and 'windows' as map)
    final hasProvenance = json.containsKey('provenance');
    final observedAtUtc = hasProvenance
        ? (safeMap(json['provenance'])['observed_at_utc'] as String? ?? '')
        : (json['observed_at_utc'] as String? ?? '');
    final computedAtUtc = hasProvenance
        ? (safeMap(json['provenance'])['computed_at_utc'] as String? ?? '')
        : (json['computed_at_utc'] as String? ?? '');

    final sourcesJson = safeMap(json['sources']);
    final producerJson = safeMap(json['producer']);
    final axesJson = safeMap(json['axes']);
    final privacyJson = safeMap(json['privacy']);
    final metaJson = safeMap(json['meta']);

    // Handle windows - can be array (wearable) or map (behavioral)
    Map<String, HsiWindow> windowsMap = {};
    List<String> windowIds = [];
    Map<String, dynamic> wearableWindowsData =
        {}; // Store full window data for wearable format

    if (json['windows'] is List) {
      // Wearable format: windows is an array of HsiDailyWindow objects
      final windowsList = json['windows'] as List<dynamic>;
      for (int i = 0; i < windowsList.length; i++) {
        final windowObj = windowsList[i];
        if (windowObj is Map<String, dynamic>) {
          // Extract date to create window ID
          final date = windowObj['date'] as String? ?? '';
          final windowId = 'w_${date}_$i';
          windowIds.add(windowId);

          // Store the full window data (sleep, physiology, activity, baseline) in meta
          wearableWindowsData[windowId] = {
            'date': date,
            'timezone': windowObj['timezone'] as String? ?? '',
            'sleep': windowObj['sleep'],
            'physiology': windowObj['physiology'],
            'activity': windowObj['activity'],
            'baseline': windowObj['baseline'],
          };

          // Create HsiWindow from the daily window structure
          // For wearable format, we'll use date/timezone as start/end placeholder
          // or extract from sleep/activity times if available
          final sleepObj = windowObj['sleep'] as Map<String, dynamic>?;
          final start =
              sleepObj?['start_time'] as String? ??
              windowObj['start'] as String? ??
              (date.isNotEmpty ? '${date}T00:00:00Z' : '');
          final end =
              sleepObj?['end_time'] as String? ??
              windowObj['end'] as String? ??
              (date.isNotEmpty ? '${date}T23:59:59Z' : '');

          windowsMap[windowId] = HsiWindow(
            start: start,
            end: end,
            label: 'daily:$date',
          );
        }
      }
    } else {
      // Behavioral format: windows is a map
      final windowsJson = safeMap(json['windows']);
      windowsMap = windowsJson.map(
        (k, v) => MapEntry(k, HsiWindow.fromJson(safeMap(v))),
      );
      windowIds = windowsMap.keys.toList();
    }

    // If window_ids is provided, use it; otherwise use keys from windows map
    if (json['window_ids'] is List) {
      windowIds = (json['window_ids'] as List<dynamic>)
          .map((e) => e.toString())
          .toList();
    }

    // Merge wearable window data into meta if present
    final mergedMeta = Map<String, dynamic>.from(metaJson);
    if (wearableWindowsData.isNotEmpty) {
      mergedMeta['wearable_windows'] = wearableWindowsData;
    }

    return HsiPayload(
      hsiVersion: json['hsi_version'] as String? ?? '1.0',
      observedAtUtc: observedAtUtc,
      computedAtUtc: computedAtUtc,
      producer: HsiProducer.fromJson(producerJson),
      windowIds: windowIds,
      windows: windowsMap,
      sourceIds:
          (json['source_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      sources: sourcesJson.map(
        (k, v) => MapEntry(k, HsiSource.fromJson(safeMap(v))),
      ),
      axes: HsiAxes.fromJson(axesJson),
      privacy: HsiPrivacy.fromJson(privacyJson),
      meta: mergedMeta,
    );
  }
}

// =============================================================================
// Legacy types for internal wearable data processing
// These are used internally and converted to HSI 1.0 axis readings for output
// =============================================================================

/// @deprecated Use HsiAxisReading instead for HSI 1.0 output
@Deprecated(
  'Use HsiAxisReading for HSI 1.0 output. Kept for internal processing.',
)
class LegacyHsiDailyWindow {
  final String date;
  final String timezone;
  final HsiSleep sleep;
  final HsiPhysiology physiology;
  final HsiActivity activity;
  final HsiBaseline baseline;

  const LegacyHsiDailyWindow({
    required this.date,
    required this.timezone,
    required this.sleep,
    required this.physiology,
    required this.activity,
    required this.baseline,
  });

  Map<String, dynamic> toJson() => {
    'date': date,
    'timezone': timezone,
    'sleep': sleep.toJson(),
    'physiology': physiology.toJson(),
    'activity': activity.toJson(),
    'baseline': baseline.toJson(),
  };
}
