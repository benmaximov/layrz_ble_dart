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

  s.resource_bundles = {'layrz_ble_privacy' => ['layrz_ble/Sources/layrz_ble/PrivacyInfo.xcprivacy']}

  s.ios.dependency 'Flutter'
  s.ios.deployment_target = '14.0'

  s.osx.dependency 'FlutterMacOS'
  s.osx.deployment_target = '11.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }

  s.resource_bundles = {
    'layrz_ble_privacy' => ['layrz_ble/Sources/layrz_ble/PrivacyInfo.xcprivacy']
  }
  s.swift_version = '5.0'
end
