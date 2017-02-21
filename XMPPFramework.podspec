Pod::Spec.new do |s|
  s.name = 'XMPPFramework'
  s.version = '3.7.0'

  s.osx.deployment_target = '10.9'
  s.ios.deployment_target = '8.0'

#  tvOS support is blocked by libidn
#  s.tvos.deployment_target = '9.0'

  s.license = { :type => 'BSD', :file => 'copying.txt' }
  s.summary = 'An XMPP Framework in Objective-C for the Mac / iOS development community.'
  s.homepage = 'https://github.com/robbiehanson/XMPPFramework'
  s.author = { 'Robbie Hanson' => 'robbiehanson@deusty.com' }
  s.source = { :git => 'https://github.com/robbiehanson/XMPPFramework.git', :tag => s.version }
  # s.source = { :git => 'https://github.com/robbiehanson/XMPPFramework.git', :branch => 'master' }
  s.resources = [ '**/*.{xcdatamodel,xcdatamodeld}']

  s.description = 'XMPPFramework provides a core implementation of RFC-3920 (the xmpp standard), along with
  the tools needed to read & write XML. It comes with multiple popular extensions (XEPs),
  all built atop a modular architecture, allowing you to plug-in any code needed for the job.
  Additionally the framework is massively parallel and thread-safe. Structured using GCD,
  this framework performs    well regardless of whether it\'s being run on an old iPhone, or
  on a 12-core Mac Pro. (And it won\'t block the main thread... at all).'

  s.requires_arc = true

  s.source_files = ['Core/**/*.{h,m}', 'Vendor/libidn/*.h',
                    'Authentication/**/*.{h,m}', 'Categories/**/*.{h,m}',
                    'Utilities/**/*.{h,m}', 'Extensions/**/*.{h,m}']
  s.ios.exclude_files = 'Extensions/SystemInputActivityMonitor/**/*.{h,m}'
  s.vendored_libraries = 'Vendor/libidn/libidn.a'
  s.libraries = 'xml2', 'resolv'
  s.frameworks = 'CoreData', 'SystemConfiguration', 'CoreLocation'
  s.xcconfig = {
    'HEADER_SEARCH_PATHS' => '$(inherited) $(SDKROOT)/usr/include/libxml2 $(SDKROOT)/usr/include/libresolv',
    'ENABLE_BITCODE' => 'NO'
  }
  s.dependency 'CocoaLumberjack', '~> 2.0'
  s.dependency 'CocoaAsyncSocket', '~> 7.5.1'
  s.dependency 'KissXML', '~> 5.2.0'
end
