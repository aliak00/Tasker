#
# Be sure to run `pod lib lint Swooft.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'Swooft'
  s.version          = '0.1.0'
  s.summary          = 'Awesome group of libs'

  s.description      = <<-DESC
A group of libraries that provide some utility
                       DESC

  s.homepage         = 'https://github.com/aliak00/Swooft'
  s.license          = { :type => 'APACHE-2', :file => 'LICENSE' }
  s.author           = { 'Ali Akhtarzada' => 'ali.akhtarzada@gmail.com' }
  s.source           = { :git => 'https://github.com/aliak00/Swooft.git', :tag => s.version.to_s }

  s.ios.deployment_target = '9.0'

  s.subspec 'Collections' do |collections|
    collections.subspec 'RingBuffer' do |ringbuffer|
      ringbuffer.source_files  = ['Swooft/Sources/Collections/RingBuffer/**/*.swift']
    end
  end

  s.subspec 'Atomics' do |atomics|
    atomics.source_files  = ['Swooft/Sources/Atomics/**/*.swift']
  end

  s.subspec 'Result' do |result|
    result.source_files  = ['Swooft/Sources/Result/**/*.swift']
  end

  s.subspec 'Logger' do |logger|
    logger.source_files  = ['Swooft/Sources/Logger/**/*.swift']
    logger.dependency 'Swooft/Collections/RingBuffer'
  end

  s.subspec 'Tasker' do |tasker|
    tasker.source_files  = ['Swooft/Sources/Tasker/**/*.swift']
    tasker.dependency 'Swooft/Atomics'
    tasker.dependency 'Swooft/Logger'
    tasker.dependency 'Swooft/Result'
  end

  s.subspec 'AsyncTask' do |asynctask|
    asynctask.source_files = ['Swooft/Sources/AsyncTask/**/*.swift']
    asynctask.dependency 'Swooft/Tasker'
  end

end
