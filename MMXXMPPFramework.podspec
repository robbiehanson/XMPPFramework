Pod::Spec.new do |s|
  s.name = 'MMXXMPPFramework'
  s.version = '3.6.11'
  # s.platform = :ios, '6.0'
  s.ios.deployment_target = '6.0'
  s.osx.deployment_target = '10.8'
  s.license = { :type => 'BSD', :file => 'copying.txt' }
  s.summary = 'An XMPP Framework in Objective-C for the Mac / iOS development community.'
  s.homepage = 'https://github.com/robbiehanson/XMPPFramework'
  s.author = { 'Robbie Hanson' => 'robbiehanson@deusty.com' }
  s.source = { :git => 'https://github.com/magnetsystems/XMPPFramework.git', :tag => '3.6.11'}
  s.resources = [ '**/*.{xcdatamodel,xcdatamodeld}']
  s.module_map = 'modulemappath/module.modulemap'
  
  s.description = 'XMPPFramework provides a core implementation of RFC-3920 (the xmpp standard), along with
  the tools needed to read & write XML. It comes with multiple popular extensions (XEPs),
  all built atop a modular architecture, allowing you to plug-in any code needed for the job.
  Additionally the framework is massively parallel and thread-safe. Structured using GCD,
  this framework performs well regardless of whether it\'s being run on an old iPhone, or
  on a 12-core Mac Pro. (And it won\'t block the main thread... at all).'
  s.requires_arc = true

  # XMPPFramework.h is used internally in the framework to let modules know
  # what other optional modules are available. Since we don't know yet which
  # subspecs have been selected, include all of them wrapped in defines which
  # will be set by the relevant subspecs.
  s.prepare_command = <<-'END'
  echo '#import "XMPP.h"' > XMPPFramework.h
  grep '#define _XMPP_' -r Extensions \
  | tr '-' '_' \
  | perl -pe 's/Extensions\/([A-z0-9_]*)\/([A-z]*.h).*/\n#ifdef HAVE_XMPP_SUBSPEC_\U\1\n\E#import "\2"\n#endif/' \
  >> XMPPFramework.h
  END

  s.subspec 'Core' do |core|
    core.source_files = ['MMXXMPPFramework-umbrella.h', 'XMPPFramework.h', 'Core/**/*.{h,m}','Vendor/libidn/*.h', 'Authentication/**/*.{h,m}', 'Categories/**/*.{h,m}', 'Utilities/**/*.{h,m}', 'Vendor/KissXML/**/*.{h,m}']
    core.vendored_libraries = 'Vendor/libidn/libidn.a'
    core.libraries = 'xml2','resolv','iconv'
    core.xcconfig = { 'HEADER_SEARCH_PATHS' => '$(SDKROOT)/usr/include/libxml2 $(SDKROOT)/usr/include/libresolv $(SDKROOT)/usr/include/libiconv',
      'LIBRARY_SEARCH_PATHS' => '"$(PODS_ROOT)/MMXXMPPFramework/Vendor/libidn"'}

      core.dependency 'CocoaLumberjack','~>1.9'
      core.dependency 'CocoaAsyncSocket','~>7.4.1'
    end

    def s.xmpp_extension(name)
      subspec name do |ss|
        ss.source_files = "Extensions/#{name}/**/*.{h,m}"
        ss.dependency 'MMXXMPPFramework/Core'
        ss.prefix_header_contents = "#define HAVE_XMPP_SUBSPEC_#{name.upcase.sub('-', '_')}"
        yield ss if block_given?
      end
    end

    s.xmpp_extension 'CoreDataStorage' do |cds|
      cds.framework = 'CoreData'
    end
    s.xmpp_extension 'Roster' do |r|
      r.dependency 'MMXXMPPFramework/CoreDataStorage'
      r.dependency 'MMXXMPPFramework/XEP-0203'
    end
    s.xmpp_extension 'Reconnect'
    s.xmpp_extension 'XEP-0060'
    s.xmpp_extension 'XEP-0082'
    s.xmpp_extension 'XEP-0106'
    s.xmpp_extension 'XEP-0203' do |x|
      x.dependency 'MMXXMPPFramework/XEP-0082'
    end
  end
