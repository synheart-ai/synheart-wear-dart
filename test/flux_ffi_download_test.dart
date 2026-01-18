import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:synheart_wear/synheart_wear.dart';
import 'package:synheart_wear/src/flux/ffi/flux_ffi.dart';

bool _isEnabled() => Platform.environment['FLUX_FFI_DOWNLOAD_TEST'] == '1';

Future<Directory> _repoRoot() async {
  // flutter test typically runs with CWD at the package root, but keep this
  // resilient so the download script can be invoked reliably.
  var dir = Directory.current;
  for (var i = 0; i < 10; i++) {
    final pubspec = File('${dir.path}/pubspec.yaml');
    if (await pubspec.exists()) return dir;
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return Directory.current;
}

void main() {
  test(
    'download Flux binaries and load via FFI (opt-in)',
    () async {
      if (!_isEnabled()) return;

      final root = await _repoRoot();

      // Download binaries into vendor/flux/** (requires curl/tar/unzip).
      final result = await Process.run(
        'bash',
        ['tool/fetch_flux_binaries.sh'],
        workingDirectory: root.path,
        runInShell: true,
      );

      if (result.exitCode != 0) {
        fail(
          'fetch_flux_binaries.sh failed (${result.exitCode})\n'
          'stdout:\n${result.stdout}\n'
          'stderr:\n${result.stderr}\n',
        );
      }

      // If any other tests have already tried to load Flux (and cached failure),
      // reset the singleton so we can attempt loading again after download.
      FluxFfi.resetForTesting();

      expect(isFluxAvailable, isTrue, reason: fluxLoadError);

      // Smoke: call into native code without needing vendor JSON.
      final processor = FluxProcessor();
      final baselinesJson = processor.saveBaselines();

      expect(baselinesJson, isNotEmpty);
      expect(() => jsonDecode(baselinesJson), returnsNormally);

      processor.dispose();
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

