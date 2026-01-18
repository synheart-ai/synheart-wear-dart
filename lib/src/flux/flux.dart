/// Synheart Flux - On-device compute engine for HSI-compliant human state signals
///
/// Flux transforms raw wearable vendor data (e.g., WHOOP, Garmin) into
/// HSI-compliant human state signals using the native Rust Flux library via FFI.
///
/// ## Quick Start
///
/// ```dart
/// import 'package:synheart_wear/flux.dart';
///
/// // Check if native library is available
/// if (!isFluxAvailable) {
///   print('Flux not available: $fluxLoadError');
///   return;
/// }
///
/// // One-shot processing (baselines reset each call)
/// final hsiPayloads = whoopToHsiDaily(
///   rawWhoopJson,
///   'America/New_York',
///   'device-123',
/// );
///
/// // Stateful processing with persistent baselines
/// final processor = FluxProcessor();
/// final results1 = processor.processWhoop(day1Json, timezone, deviceId);
/// final results2 = processor.processWhoop(day2Json, timezone, deviceId);
///
/// // Save/load baselines for persistence
/// final savedBaselines = processor.saveBaselines();
/// // ... later ...
/// processor.loadBaselines(savedBaselines);
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
/// ## HSI Output Schema
///
/// Each HSI payload includes:
/// - `hsi_version` - Schema version
/// - `producer` - Name, version, instance_id
/// - `provenance` - Source vendor, device, timestamps
/// - `quality` - Coverage, freshness, confidence, flags
/// - `windows` - Daily data with sleep, physiology, activity, baseline
///
/// ## Design Principles
///
/// 1. **Signals, not labels** - Raw metrics, not interpretations
/// 2. **Vendor-agnostic** - Consistent output regardless of source
/// 3. **On-device first** - Privacy-preserving local compute
/// 4. **Deterministic** - Same input always produces same output
/// 5. **Auditable** - Full provenance and quality metadata
library flux;

// Core types (HSI schema types)
export 'types.dart';

// FFI bindings
export 'ffi/flux_ffi.dart' show FluxFfiException, FluxNative, FluxProcessorNative;

// Main processor and convenience functions
export 'flux_processor.dart';
