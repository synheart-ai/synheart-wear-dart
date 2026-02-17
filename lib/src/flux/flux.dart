/// Synheart Flux - On-device compute engine for HSI 1.0 compliant human state signals
///
/// Flux transforms raw wearable vendor data (e.g., WHOOP, Garmin) into
/// HSI 1.0 compliant human state signals using the native Rust Flux library via FFI.
///
/// ## Flux is Optional
///
/// Flux uses graceful degradation - if the native library is not available:
/// - `isFluxAvailable` returns false
/// - Stateless functions return null instead of throwing
/// - `FluxProcessor.isAvailable` returns false
/// - Processing methods return null
///
/// This allows apps to work without Flux and implement fallback logic.
///
/// ## Quick Start
///
/// ```dart
/// import 'package:synheart_wear/flux.dart';
///
/// // Check if native library is available
/// if (!isFluxAvailable) {
///   print('Flux not available: $fluxLoadError');
///   // Use fallback processing...
///   return;
/// }
///
/// // One-shot processing (baselines reset each call)
/// final hsiPayloads = whoopToHsiDaily(
///   rawWhoopJson,
///   'America/New_York',
///   'device-123',
/// );
/// if (hsiPayloads == null) {
///   print('Processing failed');
///   return;
/// }
///
/// // Stateful processing with persistent baselines
/// final processor = FluxProcessor();
/// if (!processor.isAvailable) {
///   print('Processor not available');
///   return;
/// }
///
/// final results1 = processor.processWhoop(day1Json, timezone, deviceId);
/// final results2 = processor.processWhoop(day2Json, timezone, deviceId);
///
/// // Save/load baselines for persistence
/// final savedBaselines = processor.saveBaselines();
/// // ... later ...
/// if (savedBaselines != null) {
///   processor.loadBaselines(savedBaselines);
/// }
///
/// // Don't forget to dispose when done
/// processor.dispose();
/// ```
///
/// ## Native Library Requirements
///
/// This module requires the native Flux library to be bundled with your app.
/// See `vendor/flux/README.md` for setup instructions.
///
/// The native libraries are:
/// - Android: `libsynheart_flux.so` (bundled in jniLibs)
/// - iOS: `SynheartFlux.xcframework`
/// - macOS: `libsynheart_flux.dylib`
/// - Linux: `libsynheart_flux.so`
/// - Windows: `synheart_flux.dll`
///
/// ## HSI 1.0 Output Schema
///
/// Each HSI payload conforms to HSI 1.0 and includes:
/// - `hsi_version` - Schema version ("1.0")
/// - `observed_at_utc` - When the data was observed
/// - `computed_at_utc` - When HSI was computed
/// - `producer` - Name, version, instance_id
/// - `window_ids` / `windows` - Time windows with start/end timestamps
/// - `source_ids` / `sources` - Data sources with type and quality
/// - `axes` - Readings organized by domain (behavior, affect, engagement)
/// - `privacy` - Data handling declarations
/// - `meta` - Implementation-specific metadata
///
/// ## Design Principles
///
/// 1. **Signals, not labels** - Raw metrics, not interpretations
/// 2. **Vendor-agnostic** - Consistent output regardless of source
/// 3. **On-device first** - Privacy-preserving local compute
/// 4. **Deterministic** - Same input always produces same output
/// 5. **Auditable** - Full provenance and quality metadata
/// 6. **Optional** - Graceful degradation when native library unavailable
library flux;

// Core HSI 1.0 types
export 'types.dart'
    show
        // HSI 1.0 types
        HsiPayload,
        HsiProducer,
        HsiWindow,
        HsiSource,
        HsiSourceType,
        HsiDirection,
        HsiAxisReading,
        HsiAxesDomain,
        HsiAxes,
        HsiPrivacy,
        // Internal processing types
        Vendor,
        SleepStage,
        QualityFlag,
        CanonicalSleep,
        CanonicalRecovery,
        CanonicalActivity,
        CanonicalWearSignals,
        NormalizedSignals,
        DerivedSignals,
        Baselines,
        ContextualSignals,
        // Legacy types (kept for internal processing)
        HsiSleep,
        HsiPhysiology,
        HsiActivity,
        HsiBaseline,
        HsiDailyWindow;

// FFI bindings (for advanced use)
export 'ffi/flux_ffi.dart'
    show FluxFfiException, FluxNative, FluxProcessorNative, FluxFfi;

// Main processor and convenience functions
export 'flux_processor.dart';
