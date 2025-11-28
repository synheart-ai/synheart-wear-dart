import 'dart:io';
import '../../synheart_wear.dart';
import 'health_adapter.dart';
import 'wear_adapter.dart';
import 'healthkit_rr_channel.dart';

class AppleHealthKitAdapter implements WearAdapter {
  @override
  String get id => 'apple_healthkit';

  @override
  Set<PermissionType> get supportedPermissions => const {
        PermissionType.heartRate,
        PermissionType.heartRateVariability,
        PermissionType.steps,
        PermissionType.calories,
        PermissionType.distance,
      };

  /// Get permissions that are actually supported on the current platform
  Set<PermissionType> get _platformSupportedPermissions {
    return getPlatformSupportedPermissions();
  }

  @override
  Set<PermissionType> getPlatformSupportedPermissions() {
    if (Platform.isAndroid) {
      // Health Connect doesn't support DISTANCE_WALKING_RUNNING
      return {
        PermissionType.heartRate,
        PermissionType.heartRateVariability, // RMSSD on Android
        PermissionType.steps,
        PermissionType.calories,
        // Distance is not supported by Health Connect
      };
    } else {
      // iOS HealthKit supports all including distance
      return supportedPermissions;
    }
  }

  @override
  Future<void> ensurePermissions() async {
    // Check if HealthKit/Health Connect is available
    final isAvailable = await HealthAdapter.isAvailable();
    if (!isAvailable) {
      throw DeviceUnavailableError(
        Platform.isAndroid
            ? 'Health Connect is not available on this device'
            : 'HealthKit is not available on this device',
      );
    }

    // Request permissions using health package
    // Use platform-specific permissions (exclude HRV on Android)
    final granted =
        await HealthAdapter.requestPermissions(_platformSupportedPermissions);
    if (!granted) {
      throw PermissionDeniedError(
        Platform.isAndroid
            ? 'Health Connect permissions were denied'
            : 'HealthKit permissions were denied',
      );
    }
  }

  @override
  Future<WearMetrics?> readSnapshot({bool isRealTime = true}) async {
    try {
      // Fetch data from the last 30 days to sum all values
      final timeRange = const Duration(days: 30);

      // Read data using health package
      // Use platform-specific permissions (exclude HRV on Android)
      final dataPoints = await HealthAdapter.readHealthData(
        _platformSupportedPermissions,
        startTime: DateTime.now().subtract(timeRange),
        endTime: DateTime.now(),
      );

      // Convert to WearMetrics
      final metrics = HealthAdapter.convertToWearMetrics(
        dataPoints,
        deviceId: 'applewatch_${DateTime.now().millisecondsSinceEpoch}',
        source: id,
      );

      if (metrics != null) {
        // Attempt to enrich with RR intervals via HealthKit heartbeat series (iOS only)
        if (Platform.isIOS) {
          try {
            final rr = await HealthKitRRChannel.fetchHeartbeatSeries(
              start: DateTime.now().subtract(const Duration(minutes: 30)),
              end: DateTime.now(),
            );
            if (rr.isNotEmpty) {
              return WearMetrics(
                timestamp: metrics.timestamp,
                deviceId: metrics.deviceId,
                source: metrics.source,
                metrics: metrics.metrics,
                meta: metrics.meta,
                rrIntervalsMs: rr,
              );
            }
          } catch (e) {
            // RR intervals are optional, continue without them
            print('Could not fetch RR intervals: $e');
          }
        }
      }

      return metrics;
    } catch (e) {
      print('HealthKit read error: $e');
      return null;
    }
  }
}
