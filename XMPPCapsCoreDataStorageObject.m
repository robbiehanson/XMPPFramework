#import "XMPPCapsCoreDataStorageObject.h"
#import "XMPPCapsResourceCoreDataStorageObject.h"
#import "XMPP.h"


@implementation XMPPCapsCoreDataStorageObject 

@dynamic capabilities;

@dynamic hashStr;
@dynamic hashAlgorithm;
@dynamic capabilitiesStr;

@dynamic resources;

- (XMPPIQ *)capabilities
{
	return [[[XMPPIQ alloc] initWithXMLString:[self capabilitiesStr] error:nil] autorelease];
}

- (void)setCapabilities:(XMPPIQ *)iq
{
	self.capabilitiesStr = [iq compactXMLString];
}

@end
