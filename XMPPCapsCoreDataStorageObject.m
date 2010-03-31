#import "XMPPCapsCoreDataStorageObject.h"
#import "XMPPCapsResourceCoreDataStorageObject.h"
#import "XMPP.h"


@implementation XMPPCapsCoreDataStorageObject 

@dynamic capabilities;

@dynamic hashStr;
@dynamic hashAlgorithm;
@dynamic capabilitiesStr;

@dynamic resources;

- (NSXMLElement *)capabilities
{
	return [[[NSXMLElement alloc] initWithXMLString:[self capabilitiesStr] error:nil] autorelease];
}

- (void)setCapabilities:(NSXMLElement *)caps
{
	self.capabilitiesStr = [caps compactXMLString];
}

@end
