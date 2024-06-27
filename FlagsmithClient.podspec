#
# Be sure to run `pod lib lint FlagsmithClient.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'FlagsmithClient'
  s.version          = '3.6.2'
  s.summary          = 'iOS Client written in Swift for Flagsmith. Ship features with confidence using feature flags and remote config.'
  s.homepage         = 'https://github.com/Flagsmith/flagsmith-ios-client'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Kyle Johnson' => 'Kyle.johnson@flagsmith.com' }
  s.source           = { :git => 'https://github.com/Flagsmith/flagsmith-ios-client.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/getflagsmith'
  s.resource_bundles = {
    'Flagsmith_Privacy' => ['FlagsmithClient/Classes/PrivacyInfo.xcprivacy'],
  }

  s.ios.deployment_target = '12.0'

  s.source_files = 'FlagsmithClient/Classes/**/*'
  s.swift_versions = '5.6'
end
