/// FFI bindings for Synheart Flux Rust library
///
/// This module provides Dart FFI bindings to the native Flux library.
/// The library handles vendor data processing and HSI encoding.

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// FFI function signatures for the Flux C API

/// Stateless: Process WHOOP JSON and return HSI JSON
/// `char* flux_whoop_to_hsi_daily(const char* json, const char* timezone, const char* device_id)`
typedef FluxWhoopToHsiDailyNative = Pointer<Utf8> Function(
  Pointer<Utf8> json,
  Pointer<Utf8> timezone,
  Pointer<Utf8> deviceId,
);
typedef FluxWhoopToHsiDailyDart = Pointer<Utf8> Function(
  Pointer<Utf8> json,
  Pointer<Utf8> timezone,
  Pointer<Utf8> deviceId,
);

/// Stateless: Process Garmin JSON and return HSI JSON
/// `char* flux_garmin_to_hsi_daily(const char* json, const char* timezone, const char* device_id)`
typedef FluxGarminToHsiDailyNative = Pointer<Utf8> Function(
  Pointer<Utf8> json,
  Pointer<Utf8> timezone,
  Pointer<Utf8> deviceId,
);
typedef FluxGarminToHsiDailyDart = Pointer<Utf8> Function(
  Pointer<Utf8> json,
  Pointer<Utf8> timezone,
  Pointer<Utf8> deviceId,
);

/// Create a new FluxProcessor instance
/// `void* flux_processor_new(int32_t baseline_window_days)`
typedef FluxProcessorNewNative = Pointer<Void> Function(Int32 windowDays);
typedef FluxProcessorNewDart = Pointer<Void> Function(int windowDays);

/// Free a FluxProcessor instance
/// `void flux_processor_free(void* processor)`
typedef FluxProcessorFreeNative = Void Function(Pointer<Void> processor);
typedef FluxProcessorFreeDart = void Function(Pointer<Void> processor);

/// Process WHOOP data with stateful processor
/// `char* flux_processor_process_whoop(void* processor, const char* json, const char* timezone, const char* device_id)`
typedef FluxProcessorProcessWhoopNative = Pointer<Utf8> Function(
  Pointer<Void> processor,
  Pointer<Utf8> json,
  Pointer<Utf8> timezone,
  Pointer<Utf8> deviceId,
);
typedef FluxProcessorProcessWhoopDart = Pointer<Utf8> Function(
  Pointer<Void> processor,
  Pointer<Utf8> json,
  Pointer<Utf8> timezone,
  Pointer<Utf8> deviceId,
);

/// Process Garmin data with stateful processor
/// `char* flux_processor_process_garmin(void* processor, const char* json, const char* timezone, const char* device_id)`
typedef FluxProcessorProcessGarminNative = Pointer<Utf8> Function(
  Pointer<Void> processor,
  Pointer<Utf8> json,
  Pointer<Utf8> timezone,
  Pointer<Utf8> deviceId,
);
typedef FluxProcessorProcessGarminDart = Pointer<Utf8> Function(
  Pointer<Void> processor,
  Pointer<Utf8> json,
  Pointer<Utf8> timezone,
  Pointer<Utf8> deviceId,
);

/// Save processor baselines to JSON
/// `char* flux_processor_save_baselines(void* processor)`
typedef FluxProcessorSaveBaselinesNative = Pointer<Utf8> Function(
  Pointer<Void> processor,
);
typedef FluxProcessorSaveBaselinesDart = Pointer<Utf8> Function(
  Pointer<Void> processor,
);

/// Load processor baselines from JSON
/// `int32_t flux_processor_load_baselines(void* processor, const char* json)`
typedef FluxProcessorLoadBaselinesNative = Int32 Function(
  Pointer<Void> processor,
  Pointer<Utf8> json,
);
typedef FluxProcessorLoadBaselinesDart = int Function(
  Pointer<Void> processor,
  Pointer<Utf8> json,
);

/// Free a string returned by Flux
/// `void flux_free_string(char* ptr)`
typedef FluxFreeStringNative = Void Function(Pointer<Utf8> ptr);
typedef FluxFreeStringDart = void Function(Pointer<Utf8> ptr);

/// Get the last error message
/// `const char* flux_last_error()`
typedef FluxLastErrorNative = Pointer<Utf8> Function();
typedef FluxLastErrorDart = Pointer<Utf8> Function();

/// Native Flux library bindings
class FluxFfi {
  static FluxFfi? _instance;
  static bool _loadAttempted = false;
  static String? _loadError;
  static String? _overrideLibraryPath;

  /// Symbols that must exist in a compatible Flux native library.
  ///
  /// If a library can be opened but is missing any of these symbols, it is
  /// treated as incompatible (often due to an older/newer Flux binary being
  /// picked up from the process/CWD search path).
  static const List<String> _requiredSymbols = <String>[
    'flux_whoop_to_hsi_daily',
    'flux_garmin_to_hsi_daily',
    'flux_processor_new',
    'flux_processor_free',
    'flux_processor_process_whoop',
    'flux_processor_process_garmin',
    'flux_processor_save_baselines',
    'flux_processor_load_baselines',
    'flux_free_string',
    'flux_last_error',
    'flux_version',
  ];

  final DynamicLibrary _lib;

  late final FluxWhoopToHsiDailyDart whoopToHsiDaily;
  late final FluxGarminToHsiDailyDart garminToHsiDaily;
  late final FluxProcessorNewDart processorNew;
  late final FluxProcessorFreeDart processorFree;
  late final FluxProcessorProcessWhoopDart processorProcessWhoop;
  late final FluxProcessorProcessGarminDart processorProcessGarmin;
  late final FluxProcessorSaveBaselinesDart processorSaveBaselines;
  late final FluxProcessorLoadBaselinesDart processorLoadBaselines;
  late final FluxFreeStringDart freeString;
  late final FluxLastErrorDart lastError;

  FluxFfi._(this._lib) {
    whoopToHsiDaily = _lib
        .lookupFunction<FluxWhoopToHsiDailyNative, FluxWhoopToHsiDailyDart>(
      'flux_whoop_to_hsi_daily',
    );

    garminToHsiDaily = _lib
        .lookupFunction<FluxGarminToHsiDailyNative, FluxGarminToHsiDailyDart>(
      'flux_garmin_to_hsi_daily',
    );

    processorNew =
        _lib.lookupFunction<FluxProcessorNewNative, FluxProcessorNewDart>(
      'flux_processor_new',
    );

    processorFree =
        _lib.lookupFunction<FluxProcessorFreeNative, FluxProcessorFreeDart>(
      'flux_processor_free',
    );

    processorProcessWhoop = _lib.lookupFunction<
        FluxProcessorProcessWhoopNative, FluxProcessorProcessWhoopDart>(
      'flux_processor_process_whoop',
    );

    processorProcessGarmin = _lib.lookupFunction<
        FluxProcessorProcessGarminNative, FluxProcessorProcessGarminDart>(
      'flux_processor_process_garmin',
    );

    processorSaveBaselines = _lib.lookupFunction<
        FluxProcessorSaveBaselinesNative, FluxProcessorSaveBaselinesDart>(
      'flux_processor_save_baselines',
    );

    processorLoadBaselines = _lib.lookupFunction<
        FluxProcessorLoadBaselinesNative, FluxProcessorLoadBaselinesDart>(
      'flux_processor_load_baselines',
    );

    freeString =
        _lib.lookupFunction<FluxFreeStringNative, FluxFreeStringDart>(
      'flux_free_string',
    );

    lastError = _lib.lookupFunction<FluxLastErrorNative, FluxLastErrorDart>(
      'flux_last_error',
    );
  }

  /// Get the singleton instance of the FFI bindings
  /// Returns null if the native library is not available
  static FluxFfi? get instance {
    if (_instance != null) return _instance;
    if (_loadAttempted) return null;

    _loadAttempted = true;

    try {
      final lib = _loadLibrary();
      _instance = FluxFfi._(lib);
      return _instance;
    } catch (e) {
      _loadError = e.toString();
      return null;
    }
  }

  /// Check if the native library is available
  static bool get isAvailable => instance != null;

  /// Get the error message if the library failed to load
  static String? get loadError => _loadError;

  /// Override the native library path for the current process.
  ///
  /// This must be called **before** first access to [instance]/[isAvailable].
  /// (Once loading is attempted, Flux caches the result.)
  ///
  /// Useful for desktop apps that bundle the library in a custom location.
  static void overrideLibraryPathForProcess(String path) {
    _overrideLibraryPath = path;
  }

  /// Reset cached load state.
  ///
  /// Flux FFI uses a singleton + "load attempted" guard to avoid repeated
  /// dynamic library loading attempts. Tests that download binaries at runtime
  /// (or otherwise change library availability) can call this to force a reload.
  static void resetForTesting() {
    _instance = null;
    _loadAttempted = false;
    _loadError = null;
    _overrideLibraryPath = null;
  }

  /// Load the native library based on platform
  static DynamicLibrary _loadLibrary() {
    final errors = <String>[];

    DynamicLibrary? tryOpen(String path) {
      try {
        return DynamicLibrary.open(path);
      } catch (e) {
        errors.add('$path -> $e');
        return null;
      }
    }

    DynamicLibrary? validateSymbols(DynamicLibrary lib, String source) {
      final missing = <String>[];
      for (final symbol in _requiredSymbols) {
        try {
          // We only care whether the symbol exists, not the signature here.
          lib.lookup<NativeFunction<Void Function()>>(symbol);
        } catch (_) {
          missing.add(symbol);
        }
      }

      if (missing.isNotEmpty) {
        errors.add(
          '$source -> missing required symbols: ${missing.join(', ')}',
        );
        return null;
      }
      return lib;
    }

    DynamicLibrary? tryCandidatePath(String path) {
      final lib = tryOpen(path);
      if (lib == null) return null;
      return validateSymbols(lib, path);
    }

    // Allow overriding via API or env var (handy for desktop).
    final envOverride = Platform.environment['SYNHEART_FLUX_LIB_PATH'];
    final override = _overrideLibraryPath ?? envOverride;
    if (override != null && override.trim().isNotEmpty) {
      final lib = tryCandidatePath(override.trim());
      if (lib != null) return lib;
    }

    if (Platform.isAndroid) {
      // Bundled via android/build.gradle (jniLibs).
      final lib = tryCandidatePath('libsynheart_flux.so');
      if (lib != null) return lib;
    } else if (Platform.isIOS) {
      // Bundled via ios/synheart_wear.podspec (XCFramework); symbols are in-process.
      final lib = validateSymbols(DynamicLibrary.process(), 'DynamicLibrary.process()');
      if (lib != null) return lib;
    } else if (Platform.isMacOS) {
      // Try app bundle first, then vendored locations (best-effort). Also validate
      // symbols so we don't accidentally bind against an incompatible library.
      final direct = tryCandidatePath('libsynheart_flux.dylib');
      if (direct != null) return direct;

      for (final candidate in _vendoredDesktopCandidates(
        relativePath: 'vendor/flux/desktop/mac/macos-arm64/libsynheart_flux.dylib',
      )) {
        final lib = tryCandidatePath(candidate);
        if (lib != null) return lib;
      }
    } else if (Platform.isLinux) {
      final direct = tryCandidatePath('libsynheart_flux.so');
      if (direct != null) return direct;

      for (final candidate in _vendoredDesktopCandidates(
        relativePath: 'vendor/flux/desktop/linux/linux-x86_64/libsynheart_flux.so',
      )) {
        final lib = tryCandidatePath(candidate);
        if (lib != null) return lib;
      }
    } else if (Platform.isWindows) {
      final direct = tryCandidatePath('synheart_flux.dll');
      if (direct != null) return direct;

      for (final candidate in _vendoredDesktopCandidates(
        relativePath: 'vendor/flux/desktop/win/synheart_flux.dll',
      )) {
        final lib = tryCandidatePath(candidate);
        if (lib != null) return lib;
      }
    } else {
      throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
    }

    // If we got here, we tried reasonable options but still failed.
    throw StateError(
      'Failed to load Synheart Flux native library. Attempts:\n'
      '${errors.map((e) => '- $e').join('\n')}\n'
      'Tip: set SYNHEART_FLUX_LIB_PATH to an absolute path of the library.',
    );
  }

  static List<String> _vendoredDesktopCandidates({
    required String relativePath,
  }) {
    final candidates = <String>[];

    // 1) Relative to current working directory (common for dev/tests).
    candidates.add(relativePath);

    // 2) Relative to a user-provided vendor directory (absolute or relative).
    final vendorDir = Platform.environment['SYNHEART_FLUX_VENDOR_DIR'];
    if (vendorDir != null && vendorDir.trim().isNotEmpty) {
      candidates.add(
        '${vendorDir.trim()}/${relativePath.replaceFirst('vendor/', '')}',
      );
    }

    // 3) Walk up from CWD to find a repo/package root that contains vendor/flux/.
    final root = _findAncestorWithVendorFlux(Directory.current);
    if (root != null) {
      candidates.add('${root.path}/$relativePath');
    }

    return candidates;
  }

  static Directory? _findAncestorWithVendorFlux(Directory start) {
    var dir = start;
    for (var i = 0; i < 12; i++) {
      final vendorFlux = Directory('${dir.path}/vendor/flux');
      if (vendorFlux.existsSync()) return dir;

      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return null;
  }
}

/// Exception thrown when a Flux FFI operation fails
class FluxFfiException implements Exception {
  final String message;

  FluxFfiException(this.message);

  @override
  String toString() => 'FluxFfiException: $message';
}

/// High-level wrapper for Flux FFI operations with graceful degradation
class FluxNative {
  final FluxFfi _ffi;

  FluxNative._(this._ffi);

  /// Create a FluxNative instance if native library is available
  /// Returns null if native library is not loaded (graceful degradation)
  static FluxNative? create() {
    final ffi = FluxFfi.instance;
    if (ffi == null) return null;
    return FluxNative._(ffi);
  }

  /// Check if native Flux is available
  static bool get isAvailable => FluxFfi.isAvailable;

  /// Get the error message if Flux failed to load
  static String? get loadError => FluxFfi.loadError;

  /// Process WHOOP JSON and return HSI JSON (stateless)
  /// Returns null if processing fails (graceful degradation)
  String? whoopToHsiDaily(String json, String timezone, String deviceId) {
    final jsonPtr = json.toNativeUtf8();
    final tzPtr = timezone.toNativeUtf8();
    final devicePtr = deviceId.toNativeUtf8();

    try {
      final resultPtr = _ffi.whoopToHsiDaily(jsonPtr, tzPtr, devicePtr);

      if (resultPtr == nullptr) {
        // Log error but don't throw - graceful degradation
        final errorPtr = _ffi.lastError();
        final error =
            errorPtr != nullptr ? errorPtr.toDartString() : 'Unknown error';
        print('FluxNative: whoopToHsiDaily failed: $error');
        return null;
      }

      final result = resultPtr.toDartString();
      _ffi.freeString(resultPtr);
      return result;
    } catch (e) {
      print('FluxNative: whoopToHsiDaily exception: $e');
      return null;
    } finally {
      malloc.free(jsonPtr);
      malloc.free(tzPtr);
      malloc.free(devicePtr);
    }
  }

  /// Process Garmin JSON and return HSI JSON (stateless)
  /// Returns null if processing fails (graceful degradation)
  String? garminToHsiDaily(String json, String timezone, String deviceId) {
    final jsonPtr = json.toNativeUtf8();
    final tzPtr = timezone.toNativeUtf8();
    final devicePtr = deviceId.toNativeUtf8();

    try {
      final resultPtr = _ffi.garminToHsiDaily(jsonPtr, tzPtr, devicePtr);

      if (resultPtr == nullptr) {
        // Log error but don't throw - graceful degradation
        final errorPtr = _ffi.lastError();
        final error =
            errorPtr != nullptr ? errorPtr.toDartString() : 'Unknown error';
        print('FluxNative: garminToHsiDaily failed: $error');
        return null;
      }

      final result = resultPtr.toDartString();
      _ffi.freeString(resultPtr);
      return result;
    } catch (e) {
      print('FluxNative: garminToHsiDaily exception: $e');
      return null;
    } finally {
      malloc.free(jsonPtr);
      malloc.free(tzPtr);
      malloc.free(devicePtr);
    }
  }
}

/// Stateful Flux processor using native library with graceful degradation
class FluxProcessorNative {
  final FluxFfi _ffi;
  Pointer<Void> _handle;
  bool _disposed = false;

  FluxProcessorNative._(this._ffi, this._handle);

  /// Create a new native FluxProcessor
  /// Returns null if native library is not available (graceful degradation)
  static FluxProcessorNative? create({int baselineWindowDays = 14}) {
    final ffi = FluxFfi.instance;
    if (ffi == null) {
      print('FluxProcessorNative: Native library not available');
      return null;
    }

    try {
      final handle = ffi.processorNew(baselineWindowDays);
      if (handle == nullptr) {
        print('FluxProcessorNative: Failed to create processor handle');
        return null;
      }
      return FluxProcessorNative._(ffi, handle);
    } catch (e) {
      print('FluxProcessorNative: Exception creating processor: $e');
      return null;
    }
  }

  /// Check if native Flux is available
  static bool get isAvailable => FluxFfi.isAvailable;

  /// Check if this processor has been disposed
  bool get isDisposed => _disposed;

  /// Process WHOOP JSON and return HSI JSON
  /// Returns null if processing fails (graceful degradation)
  String? processWhoop(String json, String timezone, String deviceId) {
    if (_disposed) {
      print('FluxProcessorNative: Processor has been disposed');
      return null;
    }

    final jsonPtr = json.toNativeUtf8();
    final tzPtr = timezone.toNativeUtf8();
    final devicePtr = deviceId.toNativeUtf8();

    try {
      final resultPtr = _ffi.processorProcessWhoop(
        _handle,
        jsonPtr,
        tzPtr,
        devicePtr,
      );

      if (resultPtr == nullptr) {
        final errorPtr = _ffi.lastError();
        final error =
            errorPtr != nullptr ? errorPtr.toDartString() : 'Unknown error';
        print('FluxProcessorNative: processWhoop failed: $error');
        return null;
      }

      final result = resultPtr.toDartString();
      _ffi.freeString(resultPtr);
      return result;
    } catch (e) {
      print('FluxProcessorNative: processWhoop exception: $e');
      return null;
    } finally {
      malloc.free(jsonPtr);
      malloc.free(tzPtr);
      malloc.free(devicePtr);
    }
  }

  /// Process Garmin JSON and return HSI JSON
  /// Returns null if processing fails (graceful degradation)
  String? processGarmin(String json, String timezone, String deviceId) {
    if (_disposed) {
      print('FluxProcessorNative: Processor has been disposed');
      return null;
    }

    final jsonPtr = json.toNativeUtf8();
    final tzPtr = timezone.toNativeUtf8();
    final devicePtr = deviceId.toNativeUtf8();

    try {
      final resultPtr = _ffi.processorProcessGarmin(
        _handle,
        jsonPtr,
        tzPtr,
        devicePtr,
      );

      if (resultPtr == nullptr) {
        final errorPtr = _ffi.lastError();
        final error =
            errorPtr != nullptr ? errorPtr.toDartString() : 'Unknown error';
        print('FluxProcessorNative: processGarmin failed: $error');
        return null;
      }

      final result = resultPtr.toDartString();
      _ffi.freeString(resultPtr);
      return result;
    } catch (e) {
      print('FluxProcessorNative: processGarmin exception: $e');
      return null;
    } finally {
      malloc.free(jsonPtr);
      malloc.free(tzPtr);
      malloc.free(devicePtr);
    }
  }

  /// Save baselines to JSON
  /// Returns null if saving fails (graceful degradation)
  String? saveBaselines() {
    if (_disposed) {
      print('FluxProcessorNative: Processor has been disposed');
      return null;
    }

    try {
      final resultPtr = _ffi.processorSaveBaselines(_handle);

      if (resultPtr == nullptr) {
        final errorPtr = _ffi.lastError();
        final error =
            errorPtr != nullptr ? errorPtr.toDartString() : 'Unknown error';
        print('FluxProcessorNative: saveBaselines failed: $error');
        return null;
      }

      final result = resultPtr.toDartString();
      _ffi.freeString(resultPtr);
      return result;
    } catch (e) {
      print('FluxProcessorNative: saveBaselines exception: $e');
      return null;
    }
  }

  /// Load baselines from JSON
  /// Returns true if successful, false if failed (graceful degradation)
  bool loadBaselines(String json) {
    if (_disposed) {
      print('FluxProcessorNative: Processor has been disposed');
      return false;
    }

    final jsonPtr = json.toNativeUtf8();

    try {
      final result = _ffi.processorLoadBaselines(_handle, jsonPtr);
      if (result != 0) {
        final errorPtr = _ffi.lastError();
        final error =
            errorPtr != nullptr ? errorPtr.toDartString() : 'Unknown error';
        print('FluxProcessorNative: loadBaselines failed: $error');
        return false;
      }
      return true;
    } catch (e) {
      print('FluxProcessorNative: loadBaselines exception: $e');
      return false;
    } finally {
      malloc.free(jsonPtr);
    }
  }

  /// Dispose of the native processor
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    try {
      _ffi.processorFree(_handle);
    } catch (e) {
      print('FluxProcessorNative: dispose exception: $e');
    }
    _handle = nullptr;
  }
}
