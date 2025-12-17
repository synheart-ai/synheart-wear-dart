# Synheart Wear

[![Version](https://img.shields.io/badge/version-0.2.2-blue.svg)](https://github.com/synheart-ai/synheart_wear)
[![Flutter](https://img.shields.io/badge/flutter-%3E%3D3.22.0-blue.svg)](https://flutter.dev)
[![License](https://img.shields.io/badge/license-Apache--2.0-green.svg)](LICENSE)

> **Unified wearable SDK** for Flutter — Stream HR, HRV, steps, calories, and distance from Apple Watch, Fitbit, Garmin, Whoop, and Samsung devices with a single, standardized API.

## ✨ Features

| Feature                | Description                                 |
| ---------------------- | ------------------------------------------- |
| 📱 **Cross-Platform**  | iOS & Android support                       |
| ⌚ **Multi-Device**    | Apple Watch, Fitbit, Garmin, Whoop, Samsung |
| 🔄 **Real-Time**       | Live HR and HRV streaming                   |
| 📊 **Unified Schema**  | Consistent data format across all devices   |
| 🔒 **Privacy-First**   | Consent-based access with encryption        |
| 💾 **Offline Support** | Encrypted local data persistence            |

## 🚀 Quick Start

### Installation

```yaml
dependencies:
  synheart_wear: ^0.2.2
```

```bash
flutter pub get
```

### Basic Usage

```dart
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:synheart_wear/synheart_wear.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SDK
  final adapters = <DeviceAdapter>{
    DeviceAdapter.appleHealthKit, // Uses Health Connect on Android
  };

  final synheart = SynheartWear(
    config: SynheartWearConfig.withAdapters(adapters),
  );

  // Request permissions & initialize
  await synheart.requestPermissions(
    permissions: {
      PermissionType.heartRate,
      PermissionType.steps,
      PermissionType.calories,
    },
    reason: 'This app needs access to your health data.',
  );

  await synheart.initialize();

  // Read metrics
  final metrics = await synheart.readMetrics();
  print('HR: ${metrics.getMetric(MetricType.hr)} bpm');
  print('Steps: ${metrics.getMetric(MetricType.steps)}');
}
```

### Real-Time Streaming

```dart
// Stream heart rate every 5 seconds
synheart.streamHR(interval: Duration(seconds: 5))
  .listen((metrics) {
    final hr = metrics.getMetric(MetricType.hr);
    if (hr != null) print('Current HR: $hr bpm');
  });

// Stream HRV in 5-second windows
synheart.streamHRV(windowSize: Duration(seconds: 5))
  .listen((metrics) {
    final hrv = metrics.getMetric(MetricType.hrvRmssd);
    if (hrv != null) print('HRV RMSSD: $hrv ms');
  });
```

## 📊 Data Schema

All data follows the **Synheart Data Schema v1.0**:

```json
{
  "timestamp": "2025-10-20T18:30:00Z",
  "device_id": "applewatch_1234",
  "source": "apple_healthkit",
  "metrics": {
    "hr": 72,
    "hrv_rmssd": 45,
    "hrv_sdnn": 62,
    "steps": 1045,
    "calories": 120.4,
    "distance": 2.5
  },
  "meta": {
    "battery": 0.82,
    "firmware_version": "10.1",
    "synced": true
  }
}
```

**Access in code:**

```dart
final metrics = await synheart.readMetrics();
print(metrics.getMetric(MetricType.hr));        // 72
print(metrics.getMetric(MetricType.steps));     // 1045
print(metrics.getMetric(MetricType.distance));  // 2.5
print(metrics.batteryLevel);                     // 0.82
```

📚 **[Full API Documentation](https://synheart-ai.github.io/synheart_wear/)** | **[Data Schema Details](#data-schema-details)**

## ⌚ Supported Devices

| Device         | Platform    | Status            |
| -------------- | ----------- | ----------------- |
| Apple Watch    | iOS         | ✅ Ready          |
| Health Connect | Android     | ✅ Ready          |
| Whoop          | iOS/Android | ✅ Ready          |
| Fitbit         | iOS/Android | 🔄 In Development |
| Garmin         | iOS/Android | 🔄 In Development |
| Samsung Watch  | Android     | 📋 Planned        |

## ⚙️ Platform Configuration

### Android

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<!-- Health Connect Permissions -->
<uses-permission android:name="android.permission.health.READ_HEART_RATE"/>
<uses-permission android:name="android.permission.health.WRITE_HEART_RATE"/>
<uses-permission android:name="android.permission.health.READ_HEART_RATE_VARIABILITY"/>
<uses-permission android:name="android.permission.health.WRITE_HEART_RATE_VARIABILITY"/>
<uses-permission android:name="android.permission.health.READ_STEPS"/>
<uses-permission android:name="android.permission.health.WRITE_STEPS"/>
<uses-permission android:name="android.permission.health.READ_ACTIVE_CALORIES_BURNED"/>
<uses-permission android:name="android.permission.health.WRITE_ACTIVE_CALORIES_BURNED"/>
<uses-permission android:name="android.permission.health.READ_DISTANCE"/>
<uses-permission android:name="android.permission.health.WRITE_DISTANCE"/>

<!-- Health Connect Package Query -->
<queries>
    <package android:name="com.google.android.apps.healthdata" />
    <intent>
        <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE" />
    </intent>
</queries>

<application>
    <activity android:name=".MainActivity">
        <intent-filter>
            <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE" />
        </intent-filter>
    </activity>

    <!-- Required: Privacy Policy Activity Alias -->
    <activity-alias
        android:name="ViewPermissionUsageActivity"
        android:exported="true"
        android:targetActivity=".MainActivity"
        android:permission="android.permission.START_VIEW_PERMISSION_USAGE">
        <intent-filter>
            <action android:name="android.intent.action.VIEW_PERMISSION_USAGE" />
            <category android:name="android.intent.category.HEALTH_PERMISSIONS" />
        </intent-filter>
    </activity-alias>
</application>
```

**Note:** `MainActivity` must extend `FlutterFragmentActivity` (not `FlutterActivity`) for Android 14+.

### iOS

Add to `ios/Runner/Info.plist`:

```xml
<key>NSHealthShareUsageDescription</key>
<string>This app needs access to your health data to provide insights.</string>

<key>NSHealthUpdateUsageDescription</key>
<string>This app needs permission to update your health data.</string>
```

## ⚠️ Platform Limitations

| Platform    | Limitation                      | SDK Behavior                         |
| ----------- | ------------------------------- | ------------------------------------ |
| **Android** | HRV: Only `HRV_RMSSD` supported | Automatically maps to supported type |
| **Android** | Distance: Uses `DISTANCE_DELTA` | Automatically uses correct type      |
| **iOS**     | Full support for all metrics    | No limitations                       |

## 🔒 Privacy & Security

- ✅ Consent-first design
- ✅ AES-256-CBC encryption
- ✅ Automatic key management
- ✅ Anonymized UUIDs
- ✅ Right to forget (revoke & delete)

## 📖 Additional Resources

- **[Full API Documentation](https://synheart-ai.github.io/synheart_wear/)** — Complete API reference
- **[GitHub Issues](https://github.com/synheart-ai/synheart_wear/issues)** — Report bugs or request features
- **[pub.dev Package](https://pub.dev/packages/synheart_wear)** — Package details

---

## 📋 Detailed Sections

<details>
<summary><b>Data Schema Details</b></summary>

### Field Descriptions

| Field               | Type                | Description              | Example                                    |
| ------------------- | ------------------- | ------------------------ | ------------------------------------------ |
| `timestamp`         | `string` (ISO 8601) | When data was recorded   | `"2025-10-20T18:30:00Z"`                   |
| `device_id`         | `string`            | Unique device identifier | `"applewatch_1234"`                        |
| `source`            | `string`            | Data source adapter      | `"apple_healthkit"`, `"fitbit"`, `"whoop"` |
| `metrics.hr`        | `number`            | Heart rate (bpm)         | `72`                                       |
| `metrics.hrv_rmssd` | `number`            | HRV RMSSD (ms)           | `45`                                       |
| `metrics.hrv_sdnn`  | `number`            | HRV SDNN (ms)            | `62`                                       |
| `metrics.steps`     | `number`            | Step count               | `1045`                                     |
| `metrics.calories`  | `number`            | Calories (kcal)          | `120.4`                                    |
| `metrics.distance`  | `number`            | Distance (km)            | `2.5`                                      |
| `meta.battery`      | `number`            | Battery level (0.0-1.0)  | `0.82` (82%)                               |
| `meta.synced`       | `boolean`           | Sync status              | `true`                                     |

**Notes:**

- Optional fields may be `null` if unavailable
- Platform limitations may affect metric availability
- `meta` object may contain device-specific fields

</details>

<details>
<summary><b>Platform-Specific Permission Handling</b></summary>

```dart
Set<PermissionType> permissions;
if (Platform.isAndroid) {
  permissions = {
    PermissionType.heartRate,
    PermissionType.heartRateVariability, // RMSSD on Android
    PermissionType.steps,
    PermissionType.calories,
    // Distance supported via DISTANCE_DELTA
  };
} else {
  permissions = {
    PermissionType.heartRate,
    PermissionType.heartRateVariability,
    PermissionType.steps,
    PermissionType.calories,
    PermissionType.distance,
  };
}

final result = await synheart.requestPermissions(
  permissions: permissions,
  reason: 'This app needs access to your health data.',
);
```

</details>

<details>
<summary><b>Usage Examples</b></summary>

### Complete Health Monitoring App

```dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:synheart_wear/synheart_wear.dart';

class HealthMonitor extends StatefulWidget {
  @override
  _HealthMonitorState createState() => _HealthMonitorState();
}

class _HealthMonitorState extends State<HealthMonitor> {
  late SynheartWear _sdk;
  StreamSubscription<WearMetrics>? _hrSubscription;
  WearMetrics? _latestMetrics;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _sdk = SynheartWear(
      config: SynheartWearConfig.withAdapters({DeviceAdapter.appleHealthKit}),
    );
  }

  Future<void> _connect() async {
    try {
      final result = await _sdk.requestPermissions(
        permissions: {
          PermissionType.heartRate,
          PermissionType.steps,
          PermissionType.calories,
        },
        reason: 'This app needs access to your health data.',
      );

      if (result.values.any((s) => s == ConsentStatus.granted)) {
        await _sdk.initialize();
        final metrics = await _sdk.readMetrics();
        setState(() {
          _isConnected = true;
          _latestMetrics = metrics;
        });
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  void _startStreaming() {
    _hrSubscription = _sdk.streamHR(interval: Duration(seconds: 3))
      .listen((metrics) {
        setState(() => _latestMetrics = metrics);
      });
  }

  @override
  void dispose() {
    _hrSubscription?.cancel();
    _sdk.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Health Monitor')),
      body: _isConnected
          ? Column(
              children: [
                if (_latestMetrics != null) ...[
                  Text('HR: ${_latestMetrics!.getMetric(MetricType.hr)} bpm'),
                  Text('Steps: ${_latestMetrics!.getMetric(MetricType.steps)}'),
                ],
                ElevatedButton(
                  onPressed: _startStreaming,
                  child: Text('Start Streaming'),
                ),
              ],
            )
          : Center(
              child: ElevatedButton(
                onPressed: _connect,
                child: Text('Connect to Health'),
              ),
            ),
    );
  }
}
```

### Error Handling

```dart
try {
  final metrics = await synheart.readMetrics();
  if (metrics.hasValidData) {
    print('Data available');
  }
} on PermissionDeniedError catch (e) {
  print('Permission denied: $e');
} on DeviceUnavailableError catch (e) {
  print('Device unavailable: $e');
} on SynheartWearError catch (e) {
  print('SDK error: $e');
}
```

</details>

<details>
<summary><b>Architecture</b></summary>

```
┌─────────────────────────┐
│   synheart_wear SDK     │
├─────────────────────────┤
│ Device Adapters Layer   │
│ (Apple, Fitbit, etc.)   │
├─────────────────────────┤
│ Normalization Engine    │
│ (standard output schema)│
├─────────────────────────┤
│   Local Cache & Storage │
│   (encrypted, offline)  │
└─────────────────────────┘
```

</details>

<details>
<summary><b>Roadmap</b></summary>

| Version | Goal                    | Status         |
| ------- | ----------------------- | -------------- |
| v0.1    | Core SDK                | ✅ Complete    |
| v0.2    | Real-time streaming     | ✅ Complete    |
| v0.3    | Extended device support | 🔄 In Progress |
| v0.4    | SWIP integration        | 📋 Planned     |
| v1.0    | Public Release          | 📋 Planned     |

</details>

---

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) or:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👥 Authors

- **Israel Goytom** - _Initial work_ - [@isrugeek](https://github.com/isrugeek)
- **Synheart AI Team** - _RFC Design & Architecture_

---

**Made with ❤️ by the Synheart AI Team**

_Technology with a heartbeat._

## Patent Pending Notice

This project is provided under an open-source license. Certain underlying systems, methods, and architectures described or implemented herein may be covered by one or more pending patent applications.

Nothing in this repository grants any license, express or implied, to any patents or patent applications, except as provided by the applicable open-source license.
