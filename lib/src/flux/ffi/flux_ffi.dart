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

    DynamicLibrary tryOpen(String path) {
      try {
        return DynamicLibrary.open(path);
      } catch (e) {
        errors.add('$path -> $e');
        rethrow;
      }
    }

    // Allow overriding via API or env var (handy for desktop).
    final envOverride = Platform.environment['SYNHEART_FLUX_LIB_PATH'];
    final override = _overrideLibraryPath ?? envOverride;
    if (override != null && override.trim().isNotEmpty) {
      try {
        return tryOpen(override.trim());
      } catch (_) {
        // fall through to normal search
      }
    }

    if (Platform.isAndroid) {
      // Bundled via android/build.gradle (jniLibs).
      return tryOpen('libsynheart_flux.so');
    } else if (Platform.isIOS) {
      // Bundled via ios/synheart_wear.podspec (XCFramework); symbols are in-process.
      return DynamicLibrary.process();
    } else if (Platform.isMacOS) {
      // Try app bundle first, then vendored locations (best-effort).
      try {
        return tryOpen('libsynheart_flux.dylib');
      } catch (_) {
        final lib = _tryOpenVendoredDesktopLib(
          relativePath: 'vendor/flux/desktop/mac/macos-arm64/libsynheart_flux.dylib',
          tryOpen: tryOpen,
        );
        if (lib != null) return lib;
      }
    } else if (Platform.isLinux) {
      try {
        return tryOpen('libsynheart_flux.so');
      } catch (_) {
        final lib = _tryOpenVendoredDesktopLib(
          relativePath: 'vendor/flux/desktop/linux/linux-x86_64/libsynheart_flux.so',
          tryOpen: tryOpen,
        );
        if (lib != null) return lib;
      }
    } else if (Platform.isWindows) {
      try {
        return tryOpen('synheart_flux.dll');
      } catch (_) {
        final lib = _tryOpenVendoredDesktopLib(
          relativePath: 'vendor/flux/desktop/win/synheart_flux.dll',
          tryOpen: tryOpen,
        );
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

  static DynamicLibrary? _tryOpenVendoredDesktopLib({
    required String relativePath,
    required DynamicLibrary Function(String path) tryOpen,
  }) {
    // 1) Relative to current working directory (common for dev/tests).
    try {
      return tryOpen(relativePath);
    } catch (_) {
      // continue
    }

    // 2) Relative to a user-provided vendor directory (absolute or relative).
    final vendorDir = Platform.environment['SYNHEART_FLUX_VENDOR_DIR'];
    if (vendorDir != null && vendorDir.trim().isNotEmpty) {
      final candidate = '${vendorDir.trim()}/${relativePath.replaceFirst('vendor/', '')}';
      try {
        return tryOpen(candidate);
      } catch (_) {
        // continue
      }
    }

    // 3) Walk up from CWD to find a repo/package root that contains vendor/flux/.
    final root = _findAncestorWithVendorFlux(Directory.current);
    if (root != null) {
      final candidate = '${root.path}/$relativePath';
      try {
        return tryOpen(candidate);
      } catch (_) {
        // continue
      }
    }

    return null;
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

/// High-level wrapper for Flux FFI operations
class FluxNative {
  final FluxFfi _ffi;

  FluxNative._(this._ffi);

  /// Create a FluxNative instance if native library is available
  static FluxNative? create() {
    final ffi = FluxFfi.instance;
    if (ffi == null) return null;
    return FluxNative._(ffi);
  }

  /// Check if native Flux is available
  static bool get isAvailable => FluxFfi.isAvailable;

  /// Process WHOOP JSON and return HSI JSON (stateless)
  String whoopToHsiDaily(String json, String timezone, String deviceId) {
    final jsonPtr = json.toNativeUtf8();
    final tzPtr = timezone.toNativeUtf8();
    final devicePtr = deviceId.toNativeUtf8();

    try {
      final resultPtr = _ffi.whoopToHsiDaily(jsonPtr, tzPtr, devicePtr);

      if (resultPtr == nullptr) {
        final errorPtr = _ffi.lastError();
        final error =
            errorPtr != nullptr ? errorPtr.toDartString() : 'Unknown error';
        throw FluxFfiException(error);
      }

      final result = resultPtr.toDartString();
      _ffi.freeString(resultPtr);
      return result;
    } finally {
      malloc.free(jsonPtr);
      malloc.free(tzPtr);
      malloc.free(devicePtr);
    }
  }

  /// Process Garmin JSON and return HSI JSON (stateless)
  String garminToHsiDaily(String json, String timezone, String deviceId) {
    final jsonPtr = json.toNativeUtf8();
    final tzPtr = timezone.toNativeUtf8();
    final devicePtr = deviceId.toNativeUtf8();

    try {
      final resultPtr = _ffi.garminToHsiDaily(jsonPtr, tzPtr, devicePtr);

      if (resultPtr == nullptr) {
        final errorPtr = _ffi.lastError();
        final error =
            errorPtr != nullptr ? errorPtr.toDartString() : 'Unknown error';
        throw FluxFfiException(error);
      }

      final result = resultPtr.toDartString();
      _ffi.freeString(resultPtr);
      return result;
    } finally {
      malloc.free(jsonPtr);
      malloc.free(tzPtr);
      malloc.free(devicePtr);
    }
  }
}

/// Stateful Flux processor using native library
class FluxProcessorNative {
  final FluxFfi _ffi;
  Pointer<Void> _handle;
  bool _disposed = false;

  FluxProcessorNative._(this._ffi, this._handle);

  /// Create a new native FluxProcessor
  static FluxProcessorNative? create({int baselineWindowDays = 14}) {
    final ffi = FluxFfi.instance;
    if (ffi == null) return null;

    final handle = ffi.processorNew(baselineWindowDays);
    if (handle == nullptr) {
      return null;
    }

    return FluxProcessorNative._(ffi, handle);
  }

  /// Check if this processor has been disposed
  bool get isDisposed => _disposed;

  /// Process WHOOP JSON and return HSI JSON
  String processWhoop(String json, String timezone, String deviceId) {
    _checkNotDisposed();

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
        throw FluxFfiException(error);
      }

      final result = resultPtr.toDartString();
      _ffi.freeString(resultPtr);
      return result;
    } finally {
      malloc.free(jsonPtr);
      malloc.free(tzPtr);
      malloc.free(devicePtr);
    }
  }

  /// Process Garmin JSON and return HSI JSON
  String processGarmin(String json, String timezone, String deviceId) {
    _checkNotDisposed();

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
        throw FluxFfiException(error);
      }

      final result = resultPtr.toDartString();
      _ffi.freeString(resultPtr);
      return result;
    } finally {
      malloc.free(jsonPtr);
      malloc.free(tzPtr);
      malloc.free(devicePtr);
    }
  }

  /// Save baselines to JSON
  String saveBaselines() {
    _checkNotDisposed();

    final resultPtr = _ffi.processorSaveBaselines(_handle);

    if (resultPtr == nullptr) {
      final errorPtr = _ffi.lastError();
      final error =
          errorPtr != nullptr ? errorPtr.toDartString() : 'Unknown error';
      throw FluxFfiException(error);
    }

    final result = resultPtr.toDartString();
    _ffi.freeString(resultPtr);
    return result;
  }

  /// Load baselines from JSON
  void loadBaselines(String json) {
    _checkNotDisposed();

    final jsonPtr = json.toNativeUtf8();

    try {
      final result = _ffi.processorLoadBaselines(_handle, jsonPtr);
      if (result != 0) {
        final errorPtr = _ffi.lastError();
        final error =
            errorPtr != nullptr ? errorPtr.toDartString() : 'Unknown error';
        throw FluxFfiException(error);
      }
    } finally {
      malloc.free(jsonPtr);
    }
  }

  /// Dispose of the native processor
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _ffi.processorFree(_handle);
    _handle = nullptr;
  }

  void _checkNotDisposed() {
    if (_disposed) {
      throw StateError('FluxProcessorNative has been disposed');
    }
  }
}
