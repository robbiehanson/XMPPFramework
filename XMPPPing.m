#import "XMPPPing.h"
#import "XMPP.h"
#import "XMPPCapabilities.h"


@implementation XMPPPing

- (id)initWithStream:(XMPPStream *)aXmppStream
{
	if ((self = [super initWithStream:aXmppStream]))
	{
		pingIDs = [[NSMutableArray alloc] initWithCapacity:5];
	}
	return self;
}

- (void)dealloc
{
	[pingIDs release];
	
	[super dealloc];
}

- (NSString *)generatePingID
{
	// Generate unique ID for Ping packet
	// It's important the ID be unique as the ID is the only thing that distinguishes a pong packet
	
	NSString *pingID = [xmppStream generateUUID];
	
	// Add ping ID to list so we'll recognize it when we get a response
	[pingIDs addObject:pingID];
	
	// In case we never get a response, we want to remove the ping ID eventually,
	// or we risk an ever increasing pingIDs array.
	[NSTimer scheduledTimerWithTimeInterval:30.0
									 target:self
								   selector:@selector(removePingID:)
								   userInfo:pingID
									repeats:NO];
	
	return pingID;
}

- (void)removePingID:(NSTimer *)aTimer
{
	NSString *pingID = (NSString *)[aTimer userInfo];
	
	[pingIDs removeObject:pingID];
}

- (void)sendPingToServer
{
	NSString *pingID = [self generatePingID];
	
	// Send ping packet
	// 
	// <iq type="get" id="pingID">
	//   <ping xmlns="urn:xmpp:ping"/>
	// </iq>
	
	NSXMLElement *ping = [NSXMLElement elementWithName:@"ping" xmlns:@"urn:xmpp:ping"];
	
	NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
	[iq addAttributeWithName:@"type" stringValue:@"get"];
	[iq addAttributeWithName:@"id" stringValue:pingID];
	[iq addChild:ping];
	
	[xmppStream sendElement:iq];
}

- (void)sendPingToJID:(XMPPJID *)jid
{
	NSString *pingID = [self generatePingID];
	
	// Send ping element
	// 
	// <iq to="fullJID" type="get" id="pingID">
	//   <ping xmlns="urn:xmpp:ping"/>
	// </iq>
	
	NSXMLElement *ping = [NSXMLElement elementWithName:@"ping" xmlns:@"urn:xmpp:ping"];
	
	NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
	[iq addAttributeWithName:@"to" stringValue:[jid full]];
	[iq addAttributeWithName:@"type" stringValue:@"get"];
	[iq addAttributeWithName:@"id" stringValue:pingID];
	[iq addChild:ping];
	
	[xmppStream sendElement:iq];
}

- (void)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
	NSString *type = [[iq attributeForName:@"type"] stringValue];
	
	if ([type isEqualToString:@"result"] || [type isEqualToString:@"error"])
	{
		// Example:
		// 
		// <iq from="deusty.com" to="robbiehanson@deusty.com/work" id="abc123" type="result"/>
		
		NSString *pingID = [iq elementID];
		
		NSUInteger pingIndex = [pingIDs indexOfObject:pingID];
		if (pingIndex != NSNotFound)
		{
			[pingIDs removeObjectAtIndex:pingIndex];
			
			[multicastDelegate xmppPing:self didReceivePong:iq];
		}
	}
	else if ([type isEqualToString:@"get"])
	{
		// Example:
		// 
		// <iq from="deusty.com" to="robbiehanson@deusty.com/work" id="zhq325" type="get">
		//   <ping xmlns="urn:xmpp:ping"/>
		// </iq>
		
		NSXMLElement *ping = [iq elementForName:@"ping" xmlns:@"urn:xmpp:ping"];
		if (ping)
		{
			NSXMLElement *pong = [NSXMLElement elementWithName:@"iq"];
			[pong addAttributeWithName:@"to" stringValue:[iq fromStr]];
			[pong addAttributeWithName:@"type" stringValue:@"result"];
			[pong addAttributeWithName:@"id" stringValue:[iq elementID]];
			
			[sender sendElement:pong];
		}
	}
}

/**
 * If an XMPPCapabilites instance is used we want to advertise our support for ping.
**/
- (void)xmppCapabilities:(XMPPCapabilities *)sender willSendMyCapabilities:(NSXMLElement *)query
{
	// <query xmlns="http://jabber.org/protocol/disco#info">
	//   ...
	//   <feature var="urn:xmpp:ping"/>
	//   ...
	// </query>
	
	NSXMLElement *feature = [NSXMLElement elementWithName:@"feature"];
	[feature addAttributeWithName:@"var" stringValue:@"urn:xmpp:ping"];
	
	[query addChild:feature];
}

@end
