Pod::Spec.new do |s|
  s.name             = 'synheart_wear'
  s.version          = '0.2.0'
  s.summary          = 'Unified wearable SDK for Synheart (iOS plugin stubs)'
  s.description      = <<-DESC
Synheart Wear iOS plugin for optional HealthKit heartbeat series (RR) integration.
  DESC
  s.homepage         = 'https://github.com/synheart-ai/synheart_wear'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Synheart' => 'opensource@synheart.ai' }
  s.source           = { :path => '.' }

  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '16.0'
  s.swift_version = '5.0'
  s.static_framework = true

  # Optional: bundle the native Rust Flux engine if the XCFramework is present.
  flux_xcframework_path = '../vendor/flux/ios/SynheartFlux.xcframework'
  flux_xcframework_absolute = File.expand_path(flux_xcframework_path, __dir__)
  if File.exist?(flux_xcframework_absolute)
    s.vendored_frameworks = flux_xcframework_path
  end
end

