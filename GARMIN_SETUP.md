# Garmin Health SDK Integration Guide

This guide explains how to integrate the Garmin Health SDK with synheart_wear for real-time health data streaming from Garmin wearables.

## Prerequisites

### 1. Obtain a Garmin Health SDK License

The Garmin Health SDK is **not open source** and requires a commercial license from Garmin.

1. Contact Garmin Health to discuss licensing: https://developer.garmin.com/health-api/overview/
2. You will receive:
   - SDK license key(s) tied to your app's bundle ID / package name
   - Access to the private GitHub repositories containing the SDK

### 2. GitHub Access Token

Both iOS and Android SDKs are distributed via private GitHub repositories. You need a Personal Access Token with the following permissions:

- `read:packages`
- `repo`

Create one at: https://github.com/settings/tokens

---

## iOS Setup

### Option 1: Swift Package Manager (Recommended)

If you're using the SDK directly in your app (not through this plugin):

1. In Xcode, go to **File > Add Package Dependencies**
2. Enter: `https://github.com/garmin-health-sdk/ios-companion`
3. Authenticate with your GitHub credentials

### Option 2: Manual XCFramework Integration

For Flutter plugin integration:

1. **Download the SDK**

   Go to: https://github.com/garmin-health-sdk/ios-companion/releases

   Download the `Companion.xcframework-X.X.X.zip` file from the latest release.

2. **Extract and Copy**

   ```bash
   # Extract the downloaded file
   unzip Companion.xcframework-X.X.X.zip

   # Create the Frameworks directory in the plugin
   mkdir -p ios/Frameworks

   # Copy the XCFramework
   cp -R Companion.xcframework ios/Frameworks/
   ```

3. **Update the Podspec**

   Edit `ios/synheart_wear.podspec` and uncomment the vendored framework line:

   ```ruby
   # Change this:
   # s.vendored_frameworks = 'Frameworks/Companion.xcframework'

   # To this:
   s.vendored_frameworks = 'Frameworks/Companion.xcframework'
   ```

4. **Update Pod Configuration**

   Also uncomment the weak linking flag:

   ```ruby
   s.pod_target_xcconfig = {
     'DEFINES_MODULE' => 'YES',
     'OTHER_LDFLAGS' => '-weak_framework Companion',  # Uncomment this
   }
   ```

5. **Reinstall Pods**

   ```bash
   cd ios
   pod deintegrate
   pod install
   ```

---

## Android Setup

### Option 1: Local AAR (Recommended)

1. **Download the SDK**

   Go to: https://github.com/garmin-health-sdk/android-sdk/packages

   Choose either:
   - `companion-sdk` - For standalone apps (no Garmin Connect Mobile required)
   - `standard-sdk` - For apps used alongside Garmin Connect Mobile

   Download the AAR file from the package assets.

2. **Copy to Plugin**

   ```bash
   # Create the libs directory
   mkdir -p android/libs

   # Copy and rename the AAR
   cp garmin-health-companion-sdk-X.X.X.aar android/libs/garmin-health-sdk.aar
   ```

3. **Update build.gradle**

   Edit `android/build.gradle` and uncomment the SDK dependency:

   ```gradle
   dependencies {
       // Uncomment this line:
       implementation(name: 'garmin-health-sdk', ext: 'aar')

       // Also uncomment Guava (required by SDK):
       implementation 'com.google.guava:guava:32.1.3-android'
   }
   ```

### Option 2: Maven/GitHub Packages

1. **Set GitHub Credentials**

   Add to your app's `local.properties`:

   ```properties
   gpr.user=YOUR_GITHUB_USERNAME
   gpr.key=YOUR_GITHUB_TOKEN
   ```

   Or set environment variables:

   ```bash
   export GITHUB_USER=your_username
   export GITHUB_TOKEN=your_token
   ```

2. **Update build.gradle**

   Edit `android/build.gradle`:

   ```gradle
   // Uncomment the maven block in repositories:
   maven {
       url 'https://maven.pkg.github.com/garmin-health-sdk/android-sdk'
       credentials {
           username = project.findProperty("gpr.user") ?: System.getenv("GITHUB_USER") ?: ""
           password = project.findProperty("gpr.key") ?: System.getenv("GITHUB_TOKEN") ?: ""
       }
   }

   // And uncomment one of these in dependencies:
   implementation 'com.garmin.health:companion-sdk:4.4.0'
   // OR
   implementation 'com.garmin.health:standard-sdk:4.4.0'

   // Plus Guava:
   implementation 'com.google.guava:guava:32.1.3-android'
   ```

---

## Dart Usage

Once the SDK is configured, initialize it with your license key:

```dart
import 'package:synheart_wear/synheart_wear.dart';

// Create the Garmin adapter
final garminAdapter = GarminSdkAdapter(licenseKey: 'YOUR_LICENSE_KEY');

// Initialize the SDK
await garminAdapter.initialize();

// Check if SDK is available
final isAvailable = await garminAdapter.isAvailable();
if (!isAvailable) {
  print('Garmin SDK not available - SDK may not be linked');
  return;
}

// Get the device manager
final deviceManager = garminAdapter.deviceManager;

// Scan for devices
await deviceManager.startScanning();

// Listen for discovered devices
deviceManager.scannedDevicesStream.listen((devices) {
  for (final device in devices) {
    print('Found: ${device.name} (${device.identifier})');
  }
});

// Pair a device
final pairedDevice = await deviceManager.pairDevice(scannedDevice);

// Start real-time streaming
await deviceManager.startStreaming();

// Listen to real-time data
garminAdapter.realTimeStream.listen((data) {
  print('Heart Rate: ${data.heartRate}');
  print('Stress: ${data.stress}');
  print('HRV: ${data.hrv}');
});
```

---

## SDK Variant Comparison

| Feature | Companion SDK | Standard SDK |
|---------|--------------|--------------|
| Garmin Connect Mobile Required | No | Yes |
| Direct Bluetooth Connection | Yes | No |
| Works Offline | Yes | Yes |
| Real-time Data | Yes | Yes |
| Activity Sync | Via SDK | Via GCM |
| Platform | iOS, Android | Android only |

**Choose Companion SDK** if:
- Your users may not have Garmin Connect Mobile installed
- You need direct Bluetooth communication
- You're targeting iOS

**Choose Standard SDK** if:
- Your users will have Garmin Connect Mobile
- You want to leverage GCM's existing device connection

---

## Troubleshooting

### "SDK not available" Error

This means the SDK binary is not linked. Verify:

1. **iOS**: `Companion.xcframework` exists in `ios/Frameworks/`
2. **Android**: `garmin-health-sdk.aar` exists in `android/libs/`
3. The dependency is uncommented in podspec/build.gradle
4. You've run `pod install` (iOS) or clean build (Android)

### "License invalid" Error

- Ensure your license key matches your app's bundle ID / package name
- Contact Garmin support if the issue persists

### Bluetooth Permission Errors

**iOS**: Add to `Info.plist`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Required for Garmin device connection</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>Required for Garmin device connection</string>
```

**Android**: Add to `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

### Build Errors

**iOS - "No such module 'Companion'"**:
- The XCFramework is not properly linked
- Run `pod deintegrate && pod install`

**Android - "Unresolved reference: GarminHealth"**:
- The AAR is not found
- Check that the file exists and build.gradle dependency is uncommented

---

## Directory Structure

After setup, your project should look like:

```
synheart_wear/
├── android/
│   ├── libs/
│   │   └── garmin-health-sdk.aar    # <-- Add this
│   └── build.gradle                  # <-- Uncomment SDK dependency
├── ios/
│   ├── Frameworks/
│   │   └── Companion.xcframework/    # <-- Add this
│   └── synheart_wear.podspec         # <-- Uncomment vendored_frameworks
└── lib/
    └── ...
```

---

## Support

- **Garmin SDK Issues**: Contact Garmin Health SDK Support
- **Plugin Issues**: https://github.com/synheart-ai/synheart_wear/issues
- **SDK Documentation**: Available in the SDK release packages
