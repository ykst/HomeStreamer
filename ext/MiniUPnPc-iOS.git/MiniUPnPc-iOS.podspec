#
#  Be sure to run `pod spec lint MobileAL.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see http://docs.cocoapods.org/specification.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |s|
  s.name         = "MiniUPnPc-iOS"
  s.version      = "0.0.0"
  s.summary      = "miniupnp wrapper for iOS"

  s.description  = <<-DESC
                   DESC

  s.homepage     = "https://github.com/ykst/CocoaUPnP"
  s.license      = { :type => 'BSD', :file => 'LICENSE' }

  s.author       = { "Yohsuke Yukishita" => "ykstyhsk@gmail.com" }

  s.source       = { :git => "https://github.com/ykst/CocoaUPnP.git", :tag => "0.0.0" }

  s.source_files  = '**/*.{h,c,m}'
  s.exclude_files = 'Makefile', 'miniupnpcmodule.c', 'wingenminiupnpcstrings.c', 'minihttptestserver.c', 'upnpc.c'
  s.prefix_header_file = 'ios/Utility.h'
  s.public_header_files = 'ios/MiniUPnPc_iOS.h'
  s.requires_arc = true

  #s.subspec 'Core' do |sub|
  #  sub.source_files  = 'src/Core/*.{h,m}', 'src/Core/shaders/*.glsl'
  #  sub.public_header_files = 'src/Core/*.h'
  #end
end
