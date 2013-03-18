#import "XMPPTransports.h"
#import "XMPP.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif


@implementation XMPPTransports

@synthesize xmppStream;

- (id)initWithStream:(XMPPStream *)stream
{
	if ((self = [super init]))
	{
		xmppStream = stream;
	}
	return self;
}


/**
 * Registration process
 * @see: http://www.xmpp.org/extensions/xep-0100.html#usecases-jabber-register-pri 
**/

- (void)queryGatewayDiscoveryIdentityForLegacyService:(NSString *)service
{
	XMPPJID *myJID = xmppStream.myJID;
	
	NSString *toValue = [NSString stringWithFormat:@"%@.%@", service, [myJID domain]];
	
	// <iq type="get" from="myFullJID" to="service.domain" id="disco1">
	//   <query xmlns="http://jabber.org/protocol/disco#info"/>
	// </iq>
	
	NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"http://jabber.org/protocol/disco#info"];
	
	NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
	[iq addAttributeWithName:@"type" stringValue:@"get"];
	[iq addAttributeWithName:@"from" stringValue:[myJID full]];
	[iq addAttributeWithName:@"to" stringValue:toValue];
	[iq addAttributeWithName:@"id" stringValue:@"disco1"];
	[iq addChild:query];
	
	[xmppStream sendElement:iq];
}

- (void)queryGatewayAgentInfo
{
	XMPPJID *myJID = xmppStream.myJID;
	
	// <iq type="get" from="myFullJID" to="domain" id="agent1">
	//   <query xmlns="jabber:iq:agents"/>
	// </iq>
	
	NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"jabber:iq:agents"];
	
	NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
	[iq addAttributeWithName:@"type" stringValue:@"get"];
	[iq addAttributeWithName:@"from" stringValue:[myJID full]];
	[iq addAttributeWithName:@"to" stringValue:[myJID domain]];
	[iq addAttributeWithName:@"id" stringValue:@"agent1"];
	[iq addChild:query];
	
	[xmppStream sendElement:iq];
}

- (void)queryRegistrationRequirementsForLegacyService:(NSString *)service
{
	XMPPJID *myJID = xmppStream.myJID;
	
	NSString *toValue = [NSString stringWithFormat:@"%@.%@", service, [myJID domain]];
	
	// <iq type="get" from="myFullJID" to="service.domain" id="reg1">
	//   <query xmlns="jabber:iq:register"/>
	// </iq>
	
	NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"jabber:iq:register"];
	
	NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
	[iq addAttributeWithName:@"type" stringValue:@"get"];
	[iq addAttributeWithName:@"from" stringValue:[myJID full]];
	[iq addAttributeWithName:@"to" stringValue:toValue];
	[iq addAttributeWithName:@"id" stringValue:@"reg1"];
	[iq addChild:query];
	
	[xmppStream sendElement:iq];
}

- (void)registerLegacyService:(NSString *)service username:(NSString *)username password:(NSString *)password
{
	XMPPJID *myJID = xmppStream.myJID;
	
	NSString *toValue = [NSString stringWithFormat:@"%@.%@", service, [myJID domain]];
	
	// <iq type="set" from="myFullJID" to="service.domain" id="reg2">
	//   <query xmlns="jabber:iq:register">
	//     <username>username</username>
	//     <password>password</password>
	//   </query>
	// </iq>
	
	NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"jabber:iq:register"];
	[query addChild:[NSXMLElement elementWithName:@"username" stringValue:username]];
	[query addChild:[NSXMLElement elementWithName:@"password" stringValue:password]];
	
	NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
	[iq addAttributeWithName:@"type" stringValue:@"set"];
	[iq addAttributeWithName:@"from" stringValue:[myJID full]];
	[iq addAttributeWithName:@"to" stringValue:toValue];
	[iq addAttributeWithName:@"id" stringValue:@"reg2"];
	[iq addChild:query];
	
	[xmppStream sendElement:iq];
}

/**
 * Unregistration process
 * @see: http://www.xmpp.org/extensions/xep-0100.html#usecases-jabber-unregister-pri
**/
- (void)unregisterLegacyService:(NSString *)service
{
	XMPPJID *myJID = xmppStream.myJID;
	
	NSString *toValue = [NSString stringWithFormat:@"%@.%@", service, [myJID domain]];
	
	// <iq type="set" from="myFullJID" to="service.domain" id="unreg1">
	//   <query xmlns="jabber:iq:register">
	//     <remove/>
	//   </query>
	// </iq>
	
	NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"jabber:iq:register"];
	[query addChild:[NSXMLElement elementWithName:@"remove"]];
	
	NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
	[iq addAttributeWithName:@"type" stringValue:@"set"];
	[iq addAttributeWithName:@"from" stringValue:[myJID full]];
	[iq addAttributeWithName:@"to" stringValue:toValue];
	[iq addAttributeWithName:@"id" stringValue:@"unreg1"];
	[iq addChild:query];
	
	[xmppStream sendElement:iq];
}

@end
