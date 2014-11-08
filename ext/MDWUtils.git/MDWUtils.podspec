#
#  Be sure to run `pod spec lint MDWUtils.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see http://docs.cocoapods.org/specification.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |s|
  s.name         = "MDWUtils"
  s.version      = "0.1.0"
  s.summary      = "Cocoa categories and utilities"

  s.description  = <<-DESC
                   DESC

  s.homepage     = "https://github.com/ykst/MobileCV"
  s.license      = { :type => 'MIT', :file => 'MIT-LICENSE.txt' }

  s.author       = { "Yohsuke Yukishita" => "ykstyhsk@gmail.com" }

  s.source       = { :git => "https://bitbucket.com/ykst/MDWUtils.git", :tag => "0.1.0" }

  s.source_files  = 'src/**/*.{h,c,m}'
  s.prefix_header_file = 'src/Utility.h'
  s.public_header_files = 'src/**/*.h'
  s.requires_arc = true

  #s.subspec 'Core' do |sub|
  #  sub.source_files  = 'src/Core/*.{h,m}', 'src/Core/shaders/*.glsl'
  #  sub.public_header_files = 'src/Core/*.h'
  #end
end
