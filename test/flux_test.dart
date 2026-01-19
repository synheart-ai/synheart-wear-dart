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

    test('HSI 1.0 payload toJson includes required top-level keys', () {
      final payload = HsiPayload(
        hsiVersion: '1.0',
        observedAtUtc: '2026-01-01T00:00:00+00:00',
        computedAtUtc: '2026-01-01T00:00:01+00:00',
        producer: const HsiProducer(
          name: 'synheart_flux',
          version: '0.1.0',
          instanceId: 'test-instance',
        ),
        windowIds: ['w_test'],
        windows: {
          'w_test': const HsiWindow(
            start: '2026-01-01T00:00:00+00:00',
            end: '2026-01-01T23:59:59+00:00',
            label: 'test-window',
          ),
        },
        sourceIds: ['s_test'],
        sources: {
          's_test': const HsiSource(
            type: HsiSourceType.app,
            quality: 0.95,
            degraded: false,
          ),
        },
        axes: const HsiAxes(
          behavior: HsiAxesDomain(
            readings: [
              HsiAxisReading(
                axis: 'test_metric',
                score: 0.5,
                confidence: 0.95,
                windowId: 'w_test',
                direction: HsiDirection.higherIsMore,
                evidenceSourceIds: ['s_test'],
              ),
            ],
          ),
        ),
        privacy: const HsiPrivacy(
          containsPii: false,
          rawBiosignalsAllowed: false,
          derivedMetricsAllowed: true,
        ),
        meta: {'test_key': 'test_value'},
      );

      final json = payload.toJson();

      // HSI 1.0 required fields
      expect(json, containsPair('hsi_version', '1.0'));
      expect(json, contains('observed_at_utc'));
      expect(json, contains('computed_at_utc'));
      expect(json, contains('producer'));
      expect(json, contains('window_ids'));
      expect(json, contains('windows'));
      expect(json, contains('source_ids'));
      expect(json, contains('sources'));
      expect(json, contains('axes'));
      expect(json, contains('privacy'));

      // Ensure it is JSON encodable (no DateTime objects, etc).
      expect(() => jsonEncode(json), returnsNormally);
    });

    test('HsiPayload.fromJson roundtrips correctly', () {
      final original = HsiPayload(
        hsiVersion: '1.0',
        observedAtUtc: '2026-01-01T00:00:00+00:00',
        computedAtUtc: '2026-01-01T00:00:01+00:00',
        producer: const HsiProducer(
          name: 'test',
          version: '1.0.0',
          instanceId: 'test-id',
        ),
        windowIds: ['w_1'],
        windows: {
          'w_1': const HsiWindow(
            start: '2026-01-01T00:00:00+00:00',
            end: '2026-01-01T12:00:00+00:00',
          ),
        },
        sourceIds: ['s_1'],
        sources: {
          's_1': const HsiSource(
            type: HsiSourceType.sensor,
            quality: 0.8,
            degraded: false,
          ),
        },
        axes: const HsiAxes(),
        privacy: const HsiPrivacy(),
      );

      final json = original.toJson();
      final decoded = HsiPayload.fromJson(json);

      expect(decoded.hsiVersion, equals('1.0'));
      expect(decoded.windowIds, equals(['w_1']));
      expect(decoded.sourceIds, equals(['s_1']));
      expect(decoded.producer.name, equals('test'));
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

  group('Flux native availability (graceful degradation)', () {
    test('FluxProcessor gracefully handles unavailable native library', () {
      // FluxProcessor no longer throws - it uses graceful degradation
      final processor = FluxProcessor();

      if (!isFluxAvailable) {
        // When native library is not available, isAvailable returns false
        expect(processor.isAvailable, isFalse);
        // Methods return null instead of throwing
        expect(processor.saveBaselines(), isNull);
        expect(processor.processWhoop('{}', 'UTC', 'device-123'), isNull);
        expect(processor.currentBaselines, isNull);
      }

      processor.dispose();
    });

    test('FluxProcessor can save/load baselines when native library is available', () {
      if (!isFluxAvailable) return;

      final processor = FluxProcessor();
      expect(processor.isAvailable, isTrue);

      final baselinesJson = processor.saveBaselines();
      expect(baselinesJson, isNotNull);
      expect(baselinesJson, isNotEmpty);

      // Should roundtrip without throwing.
      expect(processor.loadBaselines(baselinesJson!), isTrue);

      // currentBaselines parses the saved JSON into Dart types.
      final baselines = processor.currentBaselines;
      expect(baselines, isNotNull);
      expect(baselines!.baselineDays, isA<int>());

      processor.dispose();
    });

    test('FluxProcessor methods return null/false after dispose', () {
      if (!isFluxAvailable) return;

      final processor = FluxProcessor();
      processor.dispose();

      // After dispose, methods return null instead of throwing (graceful degradation)
      expect(processor.isAvailable, isFalse);
      expect(processor.saveBaselines(), isNull);
      expect(processor.processWhoop('{}', 'UTC', 'device-123'), isNull);
    });

    test('isFluxAvailable reflects native library status', () {
      // This just documents the current state - doesn't assert a specific value
      // since it depends on whether native binaries are bundled
      expect(isFluxAvailable, isA<bool>());
      if (!isFluxAvailable) {
        expect(fluxLoadError, isNotNull);
      }
    });
  });
}
