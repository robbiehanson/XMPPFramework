#import "XMPPTransports.h"
#import "XMPPClient.h"
#import "XMPPJID.h"
#import "NSXMLElementAdditions.h"


@implementation XMPPTransports

- (id)initWithXMPPClient:(XMPPClient*)xmppClient
{
	if(self = [super init])
	{
		client = [xmppClient retain];
	}
	return self;
}

- (void)dealloc
{
	[client release];
	[super dealloc];
}

- (XMPPClient *)xmppClient
{
	return client;
}

/**
  * Registration process
  * @see: http://www.xmpp.org/extensions/xep-0100.html#usecases-jabber-register-pri 
 **/
- (void)queryGatewayDiscoveryIdentityForLegacyService:(NSString *)service
{
	NSXMLElement *element = [NSXMLElement elementWithName:@"iq"];
	[element addAttributeWithName:@"type" stringValue:@"get"];
	[element addAttributeWithName:@"from" stringValue:[[client myJID] full]];
	[element addAttributeWithName:@"to" stringValue:[NSString stringWithFormat:@"%@.%@", service, [client domain]]];
	[element addAttributeWithName:@"id" stringValue:@"disco1"];
	[element addChild:[NSXMLElement elementWithName:@"query" attribute:@"xmlns" stringValue:@"http://jabber.org/protocol/disco#info"]];
	
	[client sendElement:element];
}

- (void)queryGatewayAgentInfo
{
	NSXMLElement *element = [NSXMLElement elementWithName:@"iq"];
	[element addAttributeWithName:@"type" stringValue:@"get"];
	[element addAttributeWithName:@"from" stringValue:[[client myJID] full]];
	[element addAttributeWithName:@"to" stringValue:[client domain]];
	[element addAttributeWithName:@"id" stringValue:@"agent1"];
	[element addChild:[NSXMLElement elementWithName:@"query" attribute:@"xmlns" stringValue:@"jabber:iq:agents"]];
	
	[client sendElement:element];
}

- (void)queryRegistrationRequirementsForLegacyService:(NSString *)service
{
	NSXMLElement* element = [NSXMLElement elementWithName:@"iq"];
	[element addAttributeWithName:@"type" stringValue:@"get"];
	[element addAttributeWithName:@"from" stringValue:[[client myJID] full]];
	[element addAttributeWithName:@"to" stringValue:[NSString stringWithFormat:@"%@.%@", service, [client domain]]];
	[element addAttributeWithName:@"id" stringValue:@"reg1"];
	[element addChild:[NSXMLElement elementWithName:@"query" attribute:@"xmlns" stringValue:@"jabber:iq:register"]];
	
	[client sendElement:element];
}

- (void)registerLegacyService:(NSString *)service userName:(NSString *)userName password:(NSString *)password
{
	NSXMLElement *query = [NSXMLElement elementWithName:@"query" attribute:@"xmlns" stringValue:@"jabber:iq:register"];
	[query addChild:[NSXMLElement elementWithName:@"username" stringValue:userName]];
	[query addChild:[NSXMLElement elementWithName:@"password" stringValue:password]];
	
	NSXMLElement *element = [NSXMLElement elementWithName:@"iq"];
	[element addAttributeWithName:@"type" stringValue:@"set"];
	[element addAttributeWithName:@"from" stringValue:[[client myJID] full]];
	[element addAttributeWithName:@"to" stringValue:[NSString stringWithFormat:@"%@.%@", service, [client domain]]];
	[element addAttributeWithName:@"id" stringValue:@"reg2"];
	[element addChild:query];
	
	[client sendElement:element];
}

/**
 * Unregistration process
 * @see: http://www.xmpp.org/extensions/xep-0100.html#usecases-jabber-unregister-pri
**/
- (void)unregisterLegacyService:(NSString *)service
{
	NSXMLElement *query = [NSXMLElement elementWithName:@"query" attribute:@"xmlns" stringValue:@"jabber:iq:register"];
	[query addChild:[NSXMLElement elementWithName:@"remove"]];
	
	NSXMLElement *element = [NSXMLElement elementWithName:@"iq"];
	[element addAttributeWithName:@"type" stringValue:@"set"];
	[element addAttributeWithName:@"from" stringValue:[[client myJID] full]];
	[element addAttributeWithName:@"to" stringValue:[NSString stringWithFormat:@"%@.%@", service, [client domain]]];
	[element addAttributeWithName:@"id" stringValue:@"unreg1"];
	[element addChild:query];
	
	[client sendElement:element];
}

@end
