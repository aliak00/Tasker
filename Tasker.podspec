#
# Be sure to run `pod lib lint Tasker.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'Tasker'
  s.version          = '0.1.0'
  s.summary          = 'Task management framework with async await'

  s.description      = <<-DESC
A task management framework with async and await functionality
                       DESC

  s.homepage         = 'https://github.com/aliak00/Tasker'
  s.license          = { :type => 'APACHE-2', :file => 'LICENSE' }
  s.author           = { 'Ali Akhtarzada' => 'ali.akhtarzada@gmail.com' }
  s.source           = { :git => 'git@github.com:aliak00/Tasker.git', :tag => s.version.to_s }
  s.swift_version    = '4.2'

  s.ios.deployment_target = '9.0'

  s.source_files = ['Sources/**/*.swift']
end
