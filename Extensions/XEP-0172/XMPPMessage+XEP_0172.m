#import "XMPPMessage+XEP_0172.h"
#import "NSXMLElement+XMPP.h"

#define XMLNS_NICK @"http://jabber.org/protocol/nick"

@implementation XMPPMessage (XEP_0172)

- (NSString *)nick
{
	return [[self xmpp_elementForName:@"nick" xmlns:XMLNS_NICK] stringValue];
}

@end
