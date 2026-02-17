Pod::Spec.new do |s|
  s.name             = 'synheart_wear'
  s.version          = '0.2.0'
  s.summary          = 'Unified wearable SDK for Synheart (iOS plugin stubs)'
  s.description      = <<-DESC
Synheart Wear iOS plugin for optional HealthKit heartbeat series (RR) integration.
  DESC
  s.homepage         = 'https://github.com/synheart-ai/synheart_wear'
  s.license          = { :type => 'Apache-2.0', :file => '../LICENSE' }
  s.author           = { 'Synheart' => 'opensource@synheart.ai' }
  # CocoaPods validates that `source` contains a primary key (git/http/hg/svn).
  # Even when this pod is integrated via a local path (Flutter's `.symlinks`),
  # the podspec still must pass validation.
  s.source           = { :git => 'https://github.com/synheart-ai/synheart_wear.git', :tag => s.version.to_s }

  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '16.0'
  s.swift_version = '5.0'
  s.static_framework = true

  # Optional: bundle the native Rust Flux engine if the XCFramework is present.
  flux_xcframework_relative = '../vendor/flux/ios/SynheartFlux.xcframework'
  flux_xcframework = File.expand_path(flux_xcframework_relative, __dir__)
  if File.exist?(flux_xcframework)
    # Must be a relative pattern; CocoaPods rejects absolute paths here.
    s.vendored_frameworks = flux_xcframework_relative
  end
end

