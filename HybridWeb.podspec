#
# Be sure to run `pod lib lint HybridWeb.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'HybridWeb'
  s.version          = '0.1.0'
  s.summary          = 'An iOS hybrid framework.'
  s.homepage         = 'https://github.com/ws00801526/HybridWeb'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'ws00801526' => '3057600441@qq.com' }
  s.source           = { :git => 'https://github.com/ws00801526/HybridWeb.git', :tag => s.version.to_s }
  s.ios.deployment_target = '8.0'
  s.source_files = 'HybridWeb/HybridWeb.h'
  s.public_header_files = 'HybridWeb/HybridWeb.h'

  s.subspec 'Core' do |ss|
    ss.source_files = 'HybridWeb/Core/**/*.{h,m}'
    ss.public_header_files = 'HybridWeb/Core/**/*.h'
    ss.frameworks = 'WebKit'
  end

  s.subspec 'Bridge' do |ss|
    ss.source_files = 'HybridWeb/Bridge/**/*.{h,m}'
    ss.public_header_files = 'HybridWeb/Bridge/**/HBJSBridge.h', 'HybridWeb/Bridge/**/HBJSBridgeHandler.h'
    ss.frameworks = 'WebKit'
#    ss.subspec 'Event' do |sss|
#    end
#
#    ss.subspec 'Utils' do |sss|
#    end
  end

  s.subspec 'Web' do |ss|
    ss.source_files = 'HybridWeb/Web/*.{h,m}'
    ss.public_header_files = 'HybridWeb/Web/HBWebController.h', 'HybridWeb/Web/HBWebConfiguration.h'
    ss.dependency 'HybridWeb/Core'
    ss.dependency 'HybridWeb/Bridge'
    # !!!: if using resources twice, may be the assets will be copyed many times, so we used resource_bundles
    ss.resource_bundles = {
      'Web' => ['HybridWeb/Web/*.xcassets', 'HybridWeb/Web/*.{html,js,css}']
    }

    ss.subspec 'Core' do |sss|
      sss.source_files = 'HybridWeb/Web/Core/*.{h,m}'
    end
    
    ss.subspec 'Http' do |sss|
      
    end
  end
end
