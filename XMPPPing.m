#import "XMPPPing.h"
#import "XMPP.h"


@implementation XMPPPing

- (id)initWithXMPPClient:(XMPPClient *)xmppClient delegate:(id)aDelegate
{
	if((self = [super init]))
	{
		delegate = aDelegate;
		
		client = [xmppClient retain];
		[client addDelegate:self];
		
		pingIDs = [[NSMutableArray alloc] initWithCapacity:5];
	}
	return self;
}

- (void)dealloc
{
	[client removeDelegate:self];
	[client release];
	[pingIDs release];
	[super dealloc];
}

- (XMPPClient *)xmppClient
{
	return client;
}

- (id)delegate
{
	return delegate;
}

- (void)setDelegate:(id)newDelegate
{
	delegate = newDelegate;
}

- (NSString *)generatePingID
{
	// Generate unique ID for Ping packet
	// It's important the ID be unique as the ID is the only thing that distinguishes a pong packet
	CFUUIDRef uuid = CFUUIDCreate(NULL);
	NSString *pingID = [NSMakeCollectable(CFUUIDCreateString(NULL, uuid)) autorelease];
	CFRelease(uuid);
	
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
	NSXMLElement *ping = [NSXMLElement elementWithName:@"ping" xmlns:@"urn:xmpp:ping"];
	
	NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
	[iq addAttributeWithName:@"type" stringValue:@"get"];
	[iq addAttributeWithName:@"id" stringValue:pingID];
	[iq addChild:ping];
	
	[client sendElement:iq];
}

- (void)sendPingToResource:(XMPPResource *)resource
{
	NSString *pingID = [self generatePingID];
	
	// Send ping packet
	NSXMLElement *ping = [NSXMLElement elementWithName:@"ping" xmlns:@"urn:xmpp:ping"];
	
	NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
	[iq addAttributeWithName:@"to" stringValue:[[resource jid] full]];
	[iq addAttributeWithName:@"type" stringValue:@"get"];
	[iq addAttributeWithName:@"id" stringValue:pingID];
	[iq addChild:ping];
	
	[client sendElement:iq];
}

- (void)xmppClient:(XMPPClient *)sender didReceiveIQ:(XMPPIQ *)iq
{
	NSString *type = [[iq attributeForName:@"type"] stringValue];
	
	if([type isEqualToString:@"result"] || [type isEqualToString:@"error"])
	{
		// Example:
		// <iq from="deusty.com" to="robbiehanson@deusty.com/work" id="abc123" type="result">
		
		NSString *pingID = [iq elementID];
		
		NSUInteger pingIndex = [pingIDs indexOfObject:pingID];
		if(pingIndex != NSNotFound)
		{
			[pingIDs removeObjectAtIndex:pingIndex];
			
			if([delegate respondsToSelector:@selector(xmppPing:didReceivePong:)])
			{
				[delegate xmppPing:self didReceivePong:iq];
			}
		}
	}
	else if([type isEqualToString:@"get"])
	{
		// Example:
		// <iq from="deusty.com" to="robbiehanson@deusty.com/work" id="zhq325" type="get">
		//   <ping xmlns="urn:xmpp:ping"/>
		// </iq>
		
		NSXMLElement *ping = [iq elementForName:@"ping" xmlns:@"urn:xmpp:ping"];
		if(ping)
		{
			NSXMLElement *pong = [NSXMLElement elementWithName:@"iq"];
			[pong addAttributeWithName:@"to" stringValue:[iq fromStr]];
			[pong addAttributeWithName:@"type" stringValue:@"result"];
			[pong addAttributeWithName:@"id" stringValue:[iq elementID]];
			
			[client sendElement:pong];
		}
	}
}

@end
