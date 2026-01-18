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
enum SleepStage {
  awake,
  light,
  deep,
  rem,
  unknown,
}

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
        if (skinTempDeviationC != null)
          'skin_temp_deviation_c': skinTempDeviationC,
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
        sleepBaselineMinutes:
            (json['sleep_baseline_minutes'] as num?)?.toDouble(),
        sleepEfficiencyBaseline:
            (json['sleep_efficiency_baseline'] as num?)?.toDouble(),
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

/// HSI producer metadata
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
}

/// HSI provenance information
class HsiProvenance {
  final String sourceVendor;
  final String sourceDeviceId;
  final String observedAtUtc;
  final String computedAtUtc;

  const HsiProvenance({
    required this.sourceVendor,
    required this.sourceDeviceId,
    required this.observedAtUtc,
    required this.computedAtUtc,
  });

  Map<String, dynamic> toJson() => {
        'source_vendor': sourceVendor,
        'source_device_id': sourceDeviceId,
        'observed_at_utc': observedAtUtc,
        'computed_at_utc': computedAtUtc,
      };
}

/// HSI quality metrics
class HsiQuality {
  /// Data completeness (0-1)
  final double coverage;

  /// Seconds since observation
  final int freshnessSec;

  /// Overall confidence in the signals (0-1)
  final double confidence;

  /// Quality flags
  final List<String> flags;

  const HsiQuality({
    required this.coverage,
    required this.freshnessSec,
    required this.confidence,
    this.flags = const [],
  });

  Map<String, dynamic> toJson() => {
        'coverage': coverage,
        'freshness_sec': freshnessSec,
        'confidence': confidence,
        'flags': flags,
      };
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

/// HSI daily window
class HsiDailyWindow {
  final String date;
  final String timezone;
  final HsiSleep sleep;
  final HsiPhysiology physiology;
  final HsiActivity activity;
  final HsiBaseline baseline;

  const HsiDailyWindow({
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

/// Complete HSI payload
class HsiPayload {
  final String hsiVersion;
  final HsiProducer producer;
  final HsiProvenance provenance;
  final HsiQuality quality;
  final List<HsiDailyWindow> windows;

  const HsiPayload({
    required this.hsiVersion,
    required this.producer,
    required this.provenance,
    required this.quality,
    required this.windows,
  });

  Map<String, dynamic> toJson() => {
        'hsi_version': hsiVersion,
        'producer': producer.toJson(),
        'provenance': provenance.toJson(),
        'quality': quality.toJson(),
        'windows': windows.map((w) => w.toJson()).toList(),
      };
}
