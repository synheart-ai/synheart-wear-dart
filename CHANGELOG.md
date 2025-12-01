# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.1] - 2025-12-20

## [0.1.2] - 2025-12-21

### Added

- Optional RR intervals output (`rr_ms`) added to `WearMetrics` (top-level field)
- iOS HealthKit heartbeat series (RR) integration via lightweight plugin
- Example app now displays RR intervals (first few values) in Live Data

### Changed

- Apple adapter attempts heartbeat-series fetch with extended 30-minute window
- iOS deployment target for plugin set to 13.0 to support heartbeat series

### Notes

- RR availability depends on Health permissions and recent Apple Watch heartbeat series samples
- Falls back gracefully when RR is not available

### Fixed

- Fixed data freshness validation in `Normalizer` class
- Added `_isDataFresh()` method to filter out stale data based on `maxDataAge` configuration
- Data older than the configured `maxDataAge` (default 12 hours) is now properly excluded from normalization

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
