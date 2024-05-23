Pod::Spec.new do |spec|
  spec.name         = 'ScanflowText'
  spec.version      = '2.0.3'
  spec.license      =  { :type => "Commercial", :file => 'LICENCE' }
  spec.homepage     = 'https://Scanflow.ai'
  spec.authors      = 'Scanflow'
   spec.summary      = 'This framework is used to capture images from text '
 spec.description      = <<-DESC
'We are a group of AI automation enthusiasts who are passionate and dedicated about building a powerful yet simple solution for all kinds of data capture, and whether it's a simple bar code scanner or composite data capture.
Scanflow is an AI scanner promises technological solutions to any enterprise that transform any smart device camera into an intelligent data capture device for seamless scanning and workflow automation. '
                       DESC
  spec.source       = {:http => 'https://console.scanflow.ai/sdk/downloads/ScanflowText-2.0.3.framework.zip'}
  spec.vendored_frameworks = 'ScanflowText.framework'
  spec.swift_version = '5.0'
  spec.ios.deployment_target  = '9.0'
  spec.pod_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }
  spec.user_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }

end
