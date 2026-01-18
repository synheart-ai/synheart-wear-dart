/// Garmin Health SDK adapter for SynheartWear
///
/// Provides integration with Garmin wearable devices via the native
/// Garmin Health SDK (XCFramework for iOS, AAR for Android).
///
/// ## Quick Start
///
/// ```dart
/// import 'package:synheart_wear/synheart_wear.dart';
///
/// // Create adapter with license key
/// final garmin = GarminAdapter(licenseKey: 'your-license-key');
///
/// // Initialize
/// await garmin.initialize();
///
/// // Scan for devices
/// garmin.deviceManager.scannedDevicesStream.listen((devices) {
///   print('Found ${devices.length} devices');
/// });
/// await garmin.deviceManager.startScanning();
///
/// // Pair with device
/// final scannedDevice = ...; // from scannedDevicesStream
/// final pairedDevice = await garmin.deviceManager.pairDevice(scannedDevice);
///
/// // Read data
/// final metrics = await garmin.readSnapshot();
/// print('Heart Rate: ${metrics?.getMetric(MetricType.hr)}');
///
/// // Real-time streaming
/// garmin.realTimeStream.listen((data) {
///   print('HR: ${data.heartRate}, Stress: ${data.stress}');
/// });
/// await garmin.startStreaming();
/// ```
///
/// ## Features
///
/// - Device scanning and pairing
/// - Connection state monitoring
/// - Real-time data streaming (HR, HRV, stress, steps, SpO2)
/// - Logged data access (heart rate, stress, respiration)
/// - Wellness data (epochs, daily summaries)
/// - Sleep session data
/// - Activity/workout summaries
/// - WiFi sync configuration
library garmin;

// Adapter
export 'garmin_sdk_adapter.dart';
export 'garmin_device_manager.dart';
export 'garmin_platform_channel.dart';
export 'garmin_errors.dart';
