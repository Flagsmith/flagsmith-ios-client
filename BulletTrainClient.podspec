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
  s.summary          = 'iOS Client written in Swift for Bullet-Train.'
  
  s.description = <<-DESC
                    iOS Client written in Swift for Bullet-Train.
                    Ship features with confidence using feature flags and remote config. Host yourself or use our hosted version at https://bullet-train.io/
                  DESC

  s.homepage         = 'https://github.com/SolidStateGroup/bullet-train-ios-client'
  s.license          = { :type => 'BSD-3-Clause', :file => 'LICENSE' }
  s.author           = { 'Tomash Tsiupiak' => 'tomash.tsiupiak@gmail.com' }
  s.source           = { :git => 'https://github.com/SolidStateGroup/bullet-train-ios-client.git', :tag => s.version.to_s }
  s.swift_version = '5.0'

  s.ios.deployment_target = '9.3'

  s.source_files = 'BulletTrainClient/**/*'
  
  s.framework = 'Foundation'
end
