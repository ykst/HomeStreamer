#
#  Be sure to run `pod spec lint MobileAL.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see http://docs.cocoapods.org/specification.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |s|
  s.name         = "SimpleWebsocketServer"
  s.version      = "0.0.0"
  s.summary      = "Baseline websocket server for iOS app"

  s.description  = <<-DESC
                   DESC

  s.homepage     = "https://github.com/ykst/SimpleWebsocketServer"
  s.license      = { :type => 'MIT', :file => 'MIT-LICENSE.txt' }

  s.author       = { "Yohsuke Yukishita" => "ykstyhsk@gmail.com" }

  s.source       = { :git => "https://bitbucket.com/ykst/SimpleWebsocketServer.git", :tag => "0.1.0" }

  s.source_files  = 'src/**/*.{h,c,m}'
  s.exclude_files = 'Makefile'
  s.prefix_header_file = 'src/Utility.h'
  s.public_header_files = 'src/**/*.h'
  s.requires_arc = true

  #s.subspec 'Core' do |sub|
  #  sub.source_files  = 'src/Core/*.{h,m}', 'src/Core/shaders/*.glsl'
  #  sub.public_header_files = 'src/Core/*.h'
  #end
end
