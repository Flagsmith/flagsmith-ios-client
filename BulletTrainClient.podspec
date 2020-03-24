#
# Be sure to run `pod lib lint BulletTrainClient.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'BulletTrainClient'
  s.version          = '1.0.0'
  s.summary          = 'iOS Client written in Swift for Bullet-Train. Ship features with confidence using feature flags and remote config.'
  s.homepage         = 'https://github.com/SolidStateGroup/bullet-train-ios-client'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Kyle Johnson' => 'Kyle.johnson@bullet-train.io' }
  s.source           = { :git => 'https://github.com/SolidStateGroup/bullet-train-ios-client.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/getbullettrain'

  s.ios.deployment_target = '8.0'

  s.source_files = 'BulletTrainClient/Classes/**/*'
  s.swift_versions = '4.0'
end
