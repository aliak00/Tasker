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

  s.subspec 'Utils' do |utils|
    utils.subspec 'Weak' do |weak|
      weak.source_files = ['Swooft/Sources/Utils/Weak/**/*.swift']
    end
    utils.subspec 'Locking' do |locking|
      locking.source_files = ['Swooft/Sources/Utils/Locking/**/*.swift']
    end
    utils.subspec 'Array' do |array|
      array.source_files = ['Swooft/Sources/Utils/Array/**/*.swift']
    end
    utils.subspec 'Errors' do |errors|
      errors.source_files = ['Swooft/Sources/Utils/Errors/**/*.swift']
    end
  end

  s.subspec 'Collections' do |collections|
    collections.subspec 'RingBuffer' do |ringbuffer|
      ringbuffer.source_files  = ['Swooft/Sources/Collections/RingBuffer/**/*.swift']
    end
    collections.subspec 'Cache' do |cache|
      cache.source_files  = ['Swooft/Sources/Collections/Cache/**/*.swift']
      cache.dependency 'Swooft/Collections/LinkedList'
    end
    collections.subspec 'LinkedList' do |linkedlist|
      linkedlist.source_files  = ['Swooft/Sources/Collections/LinkedList/**/*.swift']
    end
    collections.subspec 'SynchronizedDictionary' do |synchronizeddictionary|
      synchronizeddictionary.source_files  = ['Swooft/Sources/Collections/SynchronizedDictionary/**/*.swift']
    end
  end

  s.subspec 'Operations' do |operations|
    operations.source_files  = ['Swooft/Sources/Operations/**/*.swift']
    operations.dependency 'Swooft/Utils/Locking'
    operations.dependency 'Swooft/Atomics'
    operations.dependency 'Swooft/Logger'
  end

  s.subspec 'Atomics' do |atomics|
    atomics.source_files  = ['Swooft/Sources/Atomics/**/*.swift']
  end

  s.subspec 'Result' do |result|
    result.source_files  = ['Swooft/Sources/Result/**/*.swift']
  end

  s.subspec 'Profiler' do |profiler|
    profiler.source_files = ['Swooft/Sources/Profiler/**/*.swift']
  end

  s.subspec 'Logger' do |logger|
    logger.source_files  = ['Swooft/Sources/Logger/**/*.swift']
    logger.dependency 'Swooft/Collections/RingBuffer'
    logger.dependency 'Swooft/Collections/Cache'
  end

  s.subspec 'Tasker' do |tasker|
    tasker.source_files  = ['Swooft/Sources/Tasker/**/*.swift']
    tasker.dependency 'Swooft/Atomics'
    tasker.dependency 'Swooft/Logger'
    tasker.dependency 'Swooft/Result'
    tasker.dependency 'Swooft/Operations'
    tasker.dependency 'Swooft/Utils/Weak'
  end

  s.subspec 'AsyncAwait' do |asynctask|
    asynctask.source_files = ['Swooft/Sources/AsyncAwait/**/*.swift']
    asynctask.dependency 'Swooft/Tasker'
  end

  s.subspec 'URLInterceptor' do |urlinterceptor|
    urlinterceptor.source_files = ['Swooft/Sources/URLInterceptor/**/*.swift']
    urlinterceptor.dependency 'Swooft/Tasker'
    urlinterceptor.dependency 'Swooft/Collections/SynchronizedDictionary'
    urlinterceptor.dependency 'Swooft/Utils/Errors'
  end

end
