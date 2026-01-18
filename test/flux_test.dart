import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:synheart_wear/synheart_wear.dart';

void main() {
  group('Flux types (pure Dart)', () {
    test('Vendor.value matches expected wire values', () {
      expect(Vendor.whoop.value, equals('whoop'));
      expect(Vendor.garmin.value, equals('garmin'));
    });

    test('Baselines JSON roundtrip', () {
      const baselines = Baselines(
        hrvBaselineMs: 42.5,
        rhrBaselineBpm: 55,
        sleepBaselineMinutes: 420,
        sleepEfficiencyBaseline: 0.9,
        baselineDays: 14,
      );

      final encoded = baselines.toJson();
      final decoded = Baselines.fromJson(encoded);

      expect(decoded.hrvBaselineMs, equals(42.5));
      expect(decoded.rhrBaselineBpm, equals(55));
      expect(decoded.sleepBaselineMinutes, equals(420));
      expect(decoded.sleepEfficiencyBaseline, equals(0.9));
      expect(decoded.baselineDays, equals(14));
    });

    test('HSI payload toJson includes required top-level keys', () {
      const payload = HsiPayload(
        hsiVersion: '1.0',
        producer: HsiProducer(name: 'synheart_flux', version: '0.0.0', instanceId: 'test'),
        provenance: HsiProvenance(
          sourceVendor: 'whoop',
          sourceDeviceId: 'device-123',
          observedAtUtc: '2026-01-01T00:00:00Z',
          computedAtUtc: '2026-01-01T00:00:00Z',
        ),
        quality: HsiQuality(coverage: 1.0, freshnessSec: 0, confidence: 1.0),
        windows: [
          HsiDailyWindow(
            date: '2026-01-01',
            timezone: 'America/New_York',
            sleep: HsiSleep(vendor: {}),
            physiology: HsiPhysiology(vendor: {}),
            activity: HsiActivity(vendor: {}),
            baseline: HsiBaseline(),
          ),
        ],
      );

      final json = payload.toJson();
      expect(json, containsPair('hsi_version', '1.0'));
      expect(json, contains('producer'));
      expect(json, contains('provenance'));
      expect(json, contains('quality'));
      expect(json, contains('windows'));

      // Ensure it is JSON encodable (no DateTime objects, etc).
      expect(() => jsonEncode(json), returnsNormally);
    });
  });

  group('Flux guards in SynheartWear (no native required)', () {
    test('readFluxSnapshot throws when Flux disabled', () async {
      final wear = SynheartWear(config: const SynheartWearConfig(enableFlux: false));

      expect(
        () => wear.readFluxSnapshot(
          vendor: Vendor.whoop,
          deviceId: 'device-123',
          timezone: 'America/New_York',
          rawVendorJson: '{}',
        ),
        throwsA(
          isA<SynheartWearError>().having((e) => e.code, 'code', equals('FLUX_DISABLED')),
        ),
      );
    });

    test('streamFluxSnapshots throws when Flux disabled', () {
      final wear = SynheartWear(config: const SynheartWearConfig(enableFlux: false));

      expect(
        () => wear.streamFluxSnapshots(
          vendor: Vendor.whoop,
          deviceId: 'device-123',
          timezone: 'America/New_York',
          fetchVendorData: () async => '{}',
        ),
        throwsA(
          isA<SynheartWearError>().having((e) => e.code, 'code', equals('FLUX_DISABLED')),
        ),
      );
    });

    test('saveFluxBaselines throws when Flux disabled', () {
      final wear = SynheartWear(config: const SynheartWearConfig(enableFlux: false));

      expect(
        () => wear.saveFluxBaselines(),
        throwsA(
          isA<SynheartWearError>().having((e) => e.code, 'code', equals('FLUX_DISABLED')),
        ),
      );
    });

    test('loadFluxBaselines throws when Flux disabled', () {
      final wear = SynheartWear(config: const SynheartWearConfig(enableFlux: false));

      expect(
        () => wear.loadFluxBaselines('{}'),
        throwsA(
          isA<SynheartWearError>().having((e) => e.code, 'code', equals('FLUX_DISABLED')),
        ),
      );
    });
  });

  group('Flux native availability (skips safely in CI)', () {
    test('FluxProcessor throws when native library is not available', () {
      if (isFluxAvailable) return;

      expect(() => FluxProcessor(), throwsA(isA<FluxNotAvailableException>()));
      expect(fluxLoadError, isNotNull);
    });

    test('FluxProcessor can save/load baselines when native library is available', () {
      if (!isFluxAvailable) return;

      final processor = FluxProcessor();
      final baselinesJson = processor.saveBaselines();
      expect(baselinesJson, isNotEmpty);

      // Should roundtrip without throwing.
      expect(() => processor.loadBaselines(baselinesJson), returnsNormally);

      // currentBaselines parses the saved JSON into Dart types.
      final baselines = processor.currentBaselines;
      expect(baselines.baselineDays, isA<int>());

      processor.dispose();
    });

    test('FluxProcessor methods throw after dispose', () {
      if (!isFluxAvailable) return;

      final processor = FluxProcessor();
      processor.dispose();

      expect(() => processor.saveBaselines(), throwsA(isA<StateError>()));
      expect(() => processor.processWhoop('{}', 'UTC', 'device-123'), throwsA(isA<StateError>()));
    });
  });
}

