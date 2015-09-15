Pod::Spec.new do |s|
s.name = 'XMPPFramework'
s.version = '3.6.6'

s.osx.deployment_target = '10.7'
s.ios.deployment_target = '6.0'

s.platform = :osx, '10.7'
s.platform = :ios, '6.0'

s.ios.frameworks = 'UIKit', 'Foundation'
s.osx.frameworks = 'Cocoa'

s.license = { :type => 'BSD', :file => 'copying.txt' }
s.summary = 'An XMPP Framework in Objective-C for the Mac / iOS development community.'
s.homepage = 'https://github.com/processOne/XMPPFramework'
s.author = { 'Robbie Hanson' => 'robbiehanson@deusty.com' }
s.source = { :git => 'https://github.com/processOne/XMPPFramework.git', :tag => s.version }
s.resources = [ '**/*.{xcdatamodel,xcdatamodeld}']

s.description = 'XMPPFramework provides a core implementation of RFC-3920 (the xmpp standard), along with
the tools needed to read & write XML. It comes with multiple popular extensions (XEPs),
all built atop a modular architecture, allowing you to plug-in any code needed for the job.
Additionally the framework is massively parallel and thread-safe. Structured using GCD,
this framework performs    well regardless of whether it\'s being run on an old iPhone, or
on a 12-core Mac Pro. (And it won\'t block the main thread... at all).'

s.requires_arc = true

# XMPPFramework.h is used internally in the framework to let modules know
# what other optional modules are available. Since we don't know yet which
# subspecs have been selected, include all of them wrapped in defines which
# will be set by the relevant subspecs.

s.prepare_command = <<-'END'
echo '#import "XMPP.h"' > XMPPFramework.h
grep '#define _XMPP_' -r /Extensions \
| tr '-' '_' \
| perl -pe 's/Extensions\/([A-z0-9_]*)\/([A-z]*.h).*/\n#ifdef HAVE_XMPP_SUBSPEC_\U\1\n\E#import "\2"\n#endif/' \
>> XMPPFramework.h
END

s.preserve_path = 'module/module.modulemap'
#s.module_map = 'module/module.modulemap'

s.subspec 'Core' do |core|
core.source_files = ['XMPPFramework.h', 'Core/**/*.{h,m}', 'Vendor/libidn/*.h', 'Authentication/**/*.{h,m}', 'Categories/**/*.{h,m}', 'Utilities/**/*.{h,m}']
core.vendored_libraries = 'Vendor/libidn/libidn.a'
core.libraries = 'xml2', 'resolv'
core.xcconfig = { 'HEADER_SEARCH_PATHS' => '$(inherited) $(SDKROOT)/usr/include/libxml2 $(PODS_ROOT)/XMPPFramework/module $(SDKROOT)/usr/include/libresolv',
'LIBRARY_SEARCH_PATHS' => '"$(PODS_ROOT)/XMPPFramework/Vendor/libidn"', 'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES', 'OTHER_LDFLAGS' => '"-lxml2"', 'ENABLE_BITCODE' => 'NO'
}
core.dependency 'CocoaLumberjack','~>1.9'
core.dependency 'CocoaAsyncSocket','~>7.4.1'
core.ios.dependency 'XMPPFramework/KissXML'
end

s.subspec 'Authentication' do |ss|
ss.dependency 'XMPPFramework/Core'
end

s.subspec 'Categories' do |ss|
ss.dependency 'XMPPFramework/Core'
end

s.subspec 'Utilities' do |ss|
ss.dependency 'XMPPFramework/Core'
end

s.subspec 'KissXML' do |ss|
ss.source_files = ['Vendor/KissXML/**/*.{h,m}', 'module/module.modulemap']
ss.libraries = 'xml2','resolv'
ss.xcconfig = {
'HEADER_SEARCH_PATHS' => '$(inherited) $(SDKROOT)/usr/include/libxml2 $(PODS_ROOT)/XMPPFramework/module $(SDKROOT)/usr/include/libresolv'
}
end

s.subspec 'BandwidthMonitor' do |ss|
ss.source_files = 'Extensions/BandwidthMonitor/**/*.{h,m}'
ss.dependency 'XMPPFramework/Core'
ss.prefix_header_contents = "#define HAVE_XMPP_SUBSPEC_#{name.upcase.sub('-', '_')}"
end

s.subspec 'CoreDataStorage' do |ss|
ss.source_files = ['Extensions/CoreDataStorage/**/*.{h,m}', 'Extensions/XEP-0203/NSXMLElement+XEP_0203.h']
ss.dependency 'XMPPFramework/Core'
ss.prefix_header_contents = "#define HAVE_XMPP_SUBSPEC_#{name.upcase.sub('-', '_')}"
ss.framework = 'CoreData'
end

s.subspec 'GoogleSharedStatus' do |ss|
ss.source_files = 'Extensions/GoogleSharedStatus/**/*.{h,m}'
ss.dependency 'XMPPFramework/Core'
ss.prefix_header_contents = "#define HAVE_XMPP_SUBSPEC_#{name.upcase.sub('-', '_')}"
end

s.subspec 'ProcessOne' do |ss|
ss.source_files = 'Extensions/ProcessOne/**/*.{h,m}'
ss.dependency 'XMPPFramework/Core'
ss.prefix_header_contents = "#define HAVE_XMPP_SUBSPEC_#{name.upcase.sub('-', '_')}"
end

s.subspec 'Reconnect' do |ss|
ss.source_files = 'Extensions/Reconnect/**/*.{h,m}'
ss.dependency 'XMPPFramework/Core'
ss.prefix_header_contents = "#define HAVE_XMPP_SUBSPEC_#{name.upcase.sub('-', '_')}"
ss.framework = 'SystemConfiguration'
end

s.subspec 'Roster' do |ss|
ss.source_files = 'Extensions/Roster/**/*.{h,m}'
ss.dependency 'XMPPFramework/Core'
ss.dependency 'XMPPFramework/CoreDataStorage'
ss.prefix_header_contents = "#define HAVE_XMPP_SUBSPEC_#{name.upcase.sub('-', '_')}"
end

s.subspec 'SystemInputActivityMonitor' do |ss|
ss.source_files = ['Extensions/SystemInputActivityMonitor/**/*.{h,m}', 'Utilities/GCDMulticastDelegate.h']
ss.dependency 'XMPPFramework/Core'
ss.prefix_header_contents = "#define HAVE_XMPP_SUBSPEC_#{name.upcase.sub('-', '_')}"
end

s.subspec 'XEP-0009' do |ss|
ss.source_files = 'Extensions/XEP-0009/**/*.{h,m}'
ss.dependency 'XMPPFramework/Core'
ss.prefix_header_contents = "#define HAVE_XMPP_SUBSPEC_#{name.upcase.sub('-', '_')}"
end

s.subspec 'XEP-0012' do |ss|
ss.source_files = 'Extensions/XEP-0012/**/*.{h,m}'
ss.dependency 'XMPPFramework/Core'
ss.prefix_header_contents = "#define HAVE_XMPP_SUBSPEC_#{name.upcase.sub('-', '_')}"
end

s.subspec 'XEP-0016' do |ss|
ss.source_files = 'Extensions/XEP-0016/**/*.{h,m}'
ss.dependency 'XMPPFramework/Core'
ss.prefix_header_contents = "#define HAVE_XMPP_SUBSPEC_#{name.upcase.sub('-', '_')}"
end

s.subspec 'XEP-0045' do |ss|
ss.source_files = 'Extensions/XEP-0045/**/*.{h,m}'
ss.dependency 'XMPPFramework/Core'
ss.dependency 'XMPPFramework/CoreDataStorage'
ss.dependency 'XMPPFramework/XEP-0203'
ss.prefix_header_contents = "#define HAVE_XMPP_SUBSPEC_#{name.upcase.sub('-', '_')}"
end

s.subspec 'XEP-0054' do |ss|
ss.source_files = ['Extensions/XEP-0054/**/*.{h,m}', 'Extensions/XEP-0153/XMPPvCardAvatarModule.h', 'Extensions/XEP-0082/XMPPDateTimeProfiles.h', 'Extensions/XEP-0082/NSDate+XMPPDateTimeProfiles.h']
ss.dependency 'XMPPFramework/Core'
ss.dependency 'XMPPFramework/Roster'
ss.prefix_header_contents = "#define HAVE_XMPP_SUBSPEC_#{name.upcase.sub('-', '_')}"
ss.framework = 'CoreLocation'
end

s.subspec 'XEP-0059' do |ss|
ss.source_files = 'Extensions/XEP-0059/**/*.{h,m}'
ss.dependency 'XMPPFramework/Core'
ss.prefix_header_contents = "#define HAVE_XMPP_SUBSPEC_#{name.upcase.sub('-', '_')}"
end

s.subspec 'XEP-0060' do |ss|
ss.source_files = 'Extensions/XEP-0060/**/*.{h,m}'
ss.dependency 'XMPPFramework/Core'
ss.prefix_header_contents = "#define HAVE_XMPP_SUBSPEC_#{name.upcase.sub('-', '_')}"
end

s.subspec 'XEP-0065' do |ss|
ss.source_files = 'Extensions/XEP-0065/**/*.{h,m}'
ss.dependency 'XMPPFramework/Core'
ss.prefix_header_contents = "#define HAVE_XMPP_SUBSPEC_#{name.upcase.sub('-', '_')}"
end

s.subspec 'XEP-0066' do |ss|
ss.source_files = 'Extensions/XEP-0066/**/*.{h,m}'
ss.dependency 'XMPPFramework/Core'
ss.prefix_header_contents = "#define HAVE_XMPP_SUBSPEC_#{name.upcase.sub('-', '_')}"
end

s.subspec 'XEP-0082' do |ss|
ss.source_files = 'Extensions/XEP-0082/**/*.{h,m}'
ss.dependency 'XMPPFramework/Core'
ss.prefix_header_contents = "#define HAVE_XMPP_SUBSPEC_#{name.upcase.sub('-', '_')}"
end

s.subspec 'XEP-0085' do |ss|
ss.source_files = 'Extensions/XEP-0085/**/*.{h,m}'
ss.dependency 'XMPPFramework/Core'
ss.prefix_header_contents = "#define HAVE_XMPP_SUBSPEC_#{name.upcase.sub('-', '_')}"
end

s.subspec 'XEP-0092' do |ss|
ss.source_files = 'Extensions/XEP-0092/**/*.{h,m}'
ss.dependency 'XMPPFramework/Core'
ss.prefix_header_contents = "#define HAVE_XMPP_SUBSPEC_#{name.upcase.sub('-', '_')}"
end

s.subspec 'XEP-0100' do |ss|
ss.source_files = 'Extensions/XEP-0100/**/*.{h,m}'
ss.dependency 'XMPPFramework/Core'
ss.prefix_header_contents = "#define HAVE_XMPP_SUBSPEC_#{name.upcase.sub('-', '_')}"
end

s.subspec 'XEP-0106' do |ss|
ss.source_files = 'Extensions/XEP-0106/**/*.{h,m}'
ss.dependency 'XMPPFramework/Core'
ss.prefix_header_contents = "#define HAVE_XMPP_SUBSPEC_#{name.upcase.sub('-', '_')}"
end

s.subspec 'XEP-0115' do |ss|
ss.source_files = 'Extensions/XEP-0115/**/*.{h,m}'
ss.dependency 'XMPPFramework/Core'
ss.dependency 'XMPPFramework/CoreDataStorage'
ss.prefix_header_contents = "#define HAVE_XMPP_SUBSPEC_#{name.upcase.sub('-', '_')}"
end

s.subspec 'XEP-0136' do |ss|
ss.source_files = 'Extensions/XEP-0136/**/*.{h,m}'
ss.dependency 'XMPPFramework/CoreDataStorage'
ss.dependency 'XMPPFramework/XEP-0203'
ss.dependency 'XMPPFramework/XEP-0085'
ss.prefix_header_contents = "#define HAVE_XMPP_SUBSPEC_#{name.upcase.sub('-', '_')}"
end

s.subspec 'XEP-0153' do |ss|
ss.source_files = ['Extensions/XEP-0153/**/*.{h,m}', 'Extensions/XEP-0082/NSDate+XMPPDateTimeProfiles.h']
ss.dependency 'XMPPFramework/Core'
ss.dependency 'XMPPFramework/XEP-0054'
ss.prefix_header_contents = "#define HAVE_XMPP_SUBSPEC_#{name.upcase.sub('-', '_')}"
end

s.subspec 'XEP-0172' do |ss|
ss.source_files = 'Extensions/XEP-0172/**/*.{h,m}'
ss.dependency 'XMPPFramework/Core'
ss.prefix_header_contents = "#define HAVE_XMPP_SUBSPEC_#{name.upcase.sub('-', '_')}"
end

s.subspec 'XEP-0184' do |ss|
ss.source_files = 'Extensions/XEP-0184/**/*.{h,m}'
ss.dependency 'XMPPFramework/Core'
ss.prefix_header_contents = "#define HAVE_XMPP_SUBSPEC_#{name.upcase.sub('-', '_')}"
end

s.subspec 'XEP-0191' do |ss|
ss.source_files = 'Extensions/XEP-0191/**/*.{h,m}'
ss.dependency 'XMPPFramework/Core'
ss.prefix_header_contents = "#define HAVE_XMPP_SUBSPEC_#{name.upcase.sub('-', '_')}"
end

s.subspec 'XEP-0198' do |ss|
ss.source_files = 'Extensions/XEP-0198/**/*.{h,m}'
ss.dependency 'XMPPFramework/Core'
ss.prefix_header_contents = "#define HAVE_XMPP_SUBSPEC_#{name.upcase.sub('-', '_')}"
end

s.subspec 'XEP-0199' do |ss|
ss.source_files = 'Extensions/XEP-0199/**/*.{h,m}'
ss.dependency 'XMPPFramework/Core'
ss.prefix_header_contents = "#define HAVE_XMPP_SUBSPEC_#{name.upcase.sub('-', '_')}"
end

s.subspec 'XEP-0202' do |ss|
ss.source_files = 'Extensions/XEP-0202/**/*.{h,m}'
ss.dependency 'XMPPFramework/Core'
ss.dependency 'XMPPFramework/XEP-0082'
ss.prefix_header_contents = "#define HAVE_XMPP_SUBSPEC_#{name.upcase.sub('-', '_')}"
end

s.subspec 'XEP-0203' do |ss|
ss.source_files = 'Extensions/XEP-0203/**/*.{h,m}'
ss.dependency 'XMPPFramework/Core'
ss.dependency 'XMPPFramework/XEP-0082'
ss.prefix_header_contents = "#define HAVE_XMPP_SUBSPEC_#{name.upcase.sub('-', '_')}"
end

s.subspec 'XEP-0223' do |ss|
ss.source_files = 'Extensions/XEP-0223/**/*.{h,m}'
ss.dependency 'XMPPFramework/Core'
ss.prefix_header_contents = "#define HAVE_XMPP_SUBSPEC_#{name.upcase.sub('-', '_')}"
end

s.subspec 'XEP-0224' do |ss|
ss.source_files = 'Extensions/XEP-0224/**/*.{h,m}'
ss.dependency 'XMPPFramework/Core'
ss.prefix_header_contents = "#define HAVE_XMPP_SUBSPEC_#{name.upcase.sub('-', '_')}"
end

s.subspec 'XEP-0280' do |ss|
ss.source_files = ['Extensions/XEP-0280/**/*.{h,m}', 'Extensions/XEP-0297/NSXMLElement+XEP_0297.h']
ss.dependency 'XMPPFramework/Core'
ss.prefix_header_contents = "#define HAVE_XMPP_SUBSPEC_#{name.upcase.sub('-', '_')}"
end

s.subspec 'XEP-0297' do |ss|
ss.source_files = ['Extensions/XEP-0297/**/*.{h,m}', 'Extensions/XEP-0203/**/*.h']
ss.dependency 'XMPPFramework/Core'
ss.dependency 'XMPPFramework/XEP-0203'
ss.prefix_header_contents = "#define HAVE_XMPP_SUBSPEC_#{name.upcase.sub('-', '_')}"
end

s.subspec 'XEP-0308' do |ss|
ss.source_files = 'Extensions/XEP-0308/**/*.{h,m}'
ss.dependency 'XMPPFramework/Core'
ss.prefix_header_contents = "#define HAVE_XMPP_SUBSPEC_#{name.upcase.sub('-', '_')}"
end

s.subspec 'XEP-0333' do |ss|
ss.source_files = 'Extensions/XEP-0333/**/*.{h,m}'
ss.dependency 'XMPPFramework/Core'
ss.prefix_header_contents = "#define HAVE_XMPP_SUBSPEC_#{name.upcase.sub('-', '_')}"
end

s.subspec 'XEP-0335' do |ss|
ss.source_files = 'Extensions/XEP-0335/**/*.{h,m}'
ss.dependency 'XMPPFramework/Core'
ss.prefix_header_contents = "#define HAVE_XMPP_SUBSPEC_#{name.upcase.sub('-', '_')}"
end
end