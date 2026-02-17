Pod::Spec.new do |s|
  s.name             = 'synheart_wear'
  s.version          = '0.2.0'
  s.summary          = 'Unified wearable SDK for Synheart (iOS plugin)'
  s.description      = <<-DESC
Synheart Wear iOS plugin for HealthKit heartbeat series (RR) integration
and optional Garmin Companion SDK integration.
  DESC
  s.homepage         = 'https://github.com/synheart-ai/synheart_wear'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Synheart' => 'opensource@synheart.ai' }
  s.source           = { :path => '.' }

  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '16.0'
  s.swift_version = '5.10'
  s.static_framework = true

  # Optional: bundle the native Rust Flux engine if the XCFramework is present.
  flux_xcframework_path = '../vendor/flux/ios/SynheartFlux.xcframework'
  flux_xcframework_absolute = File.expand_path(flux_xcframework_path, __dir__)
  if File.exist?(flux_xcframework_absolute)
    s.vendored_frameworks = flux_xcframework_path
  end

  # ============================================================================
  # GARMIN SDK INTEGRATION (Optional)
  # ============================================================================
  #
  # The Garmin Companion SDK requires a license from Garmin Health.
  # If you have a license, follow these steps:
  #
  # 1. Download the Garmin Companion SDK XCFramework from:
  #    https://github.com/garmin-health-sdk/ios-companion/releases
  #
  # 2. Extract Companion.xcframework and copy it to:
  #    <your_app>/ios/.symlinks/plugins/synheart_wear/ios/Frameworks/
  #    OR
  #    <plugin_path>/ios/Frameworks/Companion.xcframework
  #
  # 3. Uncomment the vendored_frameworks line below
  #
  # Without the SDK, Garmin methods will return "SDK not available" errors.
  # ============================================================================

  # Uncomment after adding Companion.xcframework to ios/Frameworks/
  # s.vendored_frameworks = 'Frameworks/Companion.xcframework'

  # Weak linking allows app to run if SDK framework is not present at runtime
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    # Uncomment when SDK is present to enable weak linking
    # 'OTHER_LDFLAGS' => '-weak_framework Companion',
  }

  # Required frameworks for HealthKit
  s.frameworks = 'HealthKit'
end
