# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.1] - 2025-12-26

### Added

- Comprehensive dartdoc documentation for all public APIs
- Documentation for all public classes, enums, and methods
- Enhanced enum documentation with detailed descriptions

### Changed

- Improved documentation coverage across the entire SDK
- Updated LICENSE file with complete MIT License text

### Fixed

- Fixed incomplete LICENSE file
- Added missing documentation to error classes (PermissionDeniedError, DeviceUnavailableError, NetworkError)
- Added missing documentation to adapter classes (WearAdapter, FitbitAdapter, AppleHealthKitAdapter)
- Added missing documentation to provider classes (WhoopProvider, SwipHooks)
- Added documentation to all enum values (DeviceAdapter, ConsentStatus, PermissionType, MetricType)
- Added repository field to pubspec.yaml for better pub.dev scoring

## [0.1.0] - 2025-10-27

### Added

- Initial release of synheart_wear package
- Apple HealthKit integration for iOS
- Support for multiple health metrics: heart rate (HR), heart rate variability (HRV), steps, calories
- Real-time data streaming capabilities
- Local encrypted caching for offline data persistence
- Unified data schema following the Synheart RFC specification
- Permission management system
- Data normalization engine for multi-device support
- Example Flutter app demonstrating SDK usage

### Features

- Cross-platform support (iOS and Android)
- Real-time HR and HRV streaming
- Consent-based data access
- AES-256-CBC encryption for local storage
- Automatic data quality validation
- Support for both RMSSD and SDNN HRV metrics

### Platform Support

- iOS: Full support via HealthKit integration
- Android: Under development

## [0.2.0] - 2025-12-01

### Added

- **Whoop Integration** - Full REST API integration for Whoop devices (iOS/Android)
  - OAuth 2.0 authentication flow
  - Real-time data fetching (cycles, recovery, sleep, workouts)
  - User ID persistence and configuration management
- **Health Connect/HealthKit Integration** - Native platform health data access
  - Health Connect support for Android (via `health` package v13.2.1)
  - HealthKit support for iOS
  - Unified adapter for both platforms (`AppleHealthKitAdapter`)
  - Support for HR, HRV, steps, calories, and distance metrics
- Distance metric support across both iOS and Android platforms
  - iOS: `DISTANCE_WALKING_RUNNING` via HealthKit
  - Android: `DISTANCE_DELTA` via Health Connect
- Platform configuration documentation (AndroidManifest.xml and Info.plist setup)
- Comprehensive platform configuration section in README
- WidgetsFlutterBinding.ensureInitialized() in code examples
- Improved README with collapsible sections for better readability
- Enhanced library documentation with concise, professional formatting

### Changed

- Health adapter now supports both HealthKit (iOS) and Health Connect (Android)
- Distance handling now supports both iOS (`DISTANCE_WALKING_RUNNING`) and Android (`DISTANCE_DELTA`)
- Updated `HealthAdapter` to properly map distance types per platform
- Enhanced `AppleHealthKitAdapter` to include distance in Android supported permissions
- Improved error messages and logging throughout the SDK (replaced all `print()` with proper logger)
- README restructured for better readability and scannability (reduced from 648 to 454 lines)
- Library documentation streamlined and made more concise
- Replaced all `print()` statements with `SynheartLogger` for production-ready logging

### Fixed

- Distance data retrieval on Android via Health Connect (now uses `DISTANCE_DELTA`)
- Unit conversion for distance metrics (properly handles meters, km, miles, feet, yards)
- Missing distance case in `HealthAdapter` conversion logic
- Platform-specific permission handling for distance on Android

### Documentation

- Added comprehensive platform configuration guide
- Added field descriptions table for data schema
- Added platform limitations section
- Improved code examples with proper initialization
- Enhanced API documentation with better structure

[0.1.0]: https://github.com/synheart-ai/synheart_wear/releases/tag/v0.1.0
[0.2.0]: https://github.com/synheart-ai/synheart_wear/releases/tag/v0.2.0
[0.2.1]: https://github.com/synheart-ai/synheart_wear/releases/tag/v0.2.1
