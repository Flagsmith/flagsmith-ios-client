#
# CocoaPods trunk stops accepting new versions on 2 December 2026, so this pod
# is frozen on trunk at 3.13.0 and we no longer publish to it. Swift Package
# Manager is the supported route.
#
# This spec is kept, and release-please keeps bumping its version, so that it
# stays consistent with the tag it ships on. `s.source` resolves to
# "v#{s.version}", so a stale version here would point at the wrong tag for
# anyone consuming this pod from a private specs repo or a direct git reference.
#
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'FlagsmithClient'
  s.version          = '3.13.1'  # x-release-please-version
  s.summary          = 'iOS Client written in Swift for Flagsmith. Ship features with confidence using feature flags and remote config.'
  s.homepage         = 'https://github.com/Flagsmith/flagsmith-ios-client'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Kyle Johnson' => 'Kyle.johnson@flagsmith.com' }
  s.source           = { :git => 'https://github.com/Flagsmith/flagsmith-ios-client.git', :tag => "v#{s.version}" }
  s.social_media_url = 'https://twitter.com/getflagsmith'
  s.resource_bundles = {
    'Flagsmith_Privacy' => ['FlagsmithClient/Classes/PrivacyInfo.xcprivacy'],
  }

  s.ios.deployment_target = '12.0'

  s.source_files = 'FlagsmithClient/Classes/**/*'
  s.swift_versions = '5.6'
end
