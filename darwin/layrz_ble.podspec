#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint layrz_ble.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'layrz_ble'
  s.version          = '0.0.1'
  s.summary          = 'A new Flutter plugin project.'
  s.description      = <<-DESC
A new Flutter plugin project.
                       DESC
  s.homepage         = 'https://layrz.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Golden M, Inc' => 'software@goldenm.com' }
  s.source           = { :path => '.' }
  s.source_files = 'layrz_ble/Sources/**/*.swift'

  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  s.ios.deployment_target = '14.0'
  s.osx.deployment_target = '11.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
