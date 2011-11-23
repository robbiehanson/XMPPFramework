#import "XMPPCapsCoreDataStorageObject.h"
#import "XMPPCapsResourceCoreDataStorageObject.h"
#import "XMPP.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif


@implementation XMPPCapsCoreDataStorageObject 

@dynamic capabilities;

@dynamic hashStr;
@dynamic hashAlgorithm;
@dynamic capabilitiesStr;

@dynamic resources;

- (NSXMLElement *)capabilities
{
	return [[NSXMLElement alloc] initWithXMLString:[self capabilitiesStr] error:nil];
}

- (void)setCapabilities:(NSXMLElement *)caps
{
	self.capabilitiesStr = [caps compactXMLString];
}

@end
