#import "XMPPPing.h"
#import "XMPP.h"

#define DEFAULT_TIMEOUT 30.0 // seconds

#define INTEGRATE_WITH_CAPABILITIES 1

#if INTEGRATE_WITH_CAPABILITIES
  #import "XMPPCapabilities.h"
#endif

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface XMPPPingInfo : NSObject
{
	NSDate *timeSent;
	NSTimeInterval timeout;
}

+ (XMPPPingInfo *)pingInfoWithTimeout:(NSTimeInterval)timeout;

@property (nonatomic, readonly) NSDate *timeSent;
@property (nonatomic, readonly) NSTimeInterval timeout;

- (NSTimeInterval)rtt;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPPing

- (id)initWithStream:(XMPPStream *)aXmppStream
{
	if ((self = [super initWithStream:aXmppStream]))
	{
		pingIDs = [[NSMutableDictionary alloc] initWithCapacity:5];
		
	  #if INTEGRATE_WITH_CAPABILITIES
		[xmppStream autoAddDelegate:self toModulesOfClass:[XMPPCapabilities class]];
	  #endif
	}
	return self;
}

- (void)dealloc
{
  #if INTEGRATE_WITH_CAPABILITIES
	[xmppStream removeAutoDelegate:self fromModulesOfClass:[XMPPCapabilities class]];
  #endif
	
	[pingIDs release];
	
	[super dealloc];
}

- (NSString *)generatePingIDWithTimeout:(NSTimeInterval)timeout
{
	// Generate unique ID for Ping packet
	// It's important the ID be unique as the ID is the only thing that distinguishes a pong packet
	
	NSString *pingID = [xmppStream generateUUID];
	
	// Add ping ID to list so we'll recognize it when we get a response
	[pingIDs setObject:[XMPPPingInfo pingInfoWithTimeout:timeout]
	            forKey:pingID];
	
	// In case we never get a response, we want to remove the ping ID eventually,
	// or we risk an ever increasing pingIDs array.
	[NSTimer scheduledTimerWithTimeInterval:timeout
									 target:self
								   selector:@selector(removePingID:)
								   userInfo:pingID
									repeats:NO];
	
	return pingID;
}

- (void)removePingID:(NSTimer *)aTimer
{
	NSString *pingID = (NSString *)[aTimer userInfo];
	
	XMPPPingInfo *pingInfo = [pingIDs objectForKey:pingID];
	if (pingInfo)
	{
		[pingInfo retain];
		[pingIDs removeObjectForKey:pingID];
		
		[multicastDelegate xmppPing:self didNotReceivePong:pingID dueToTimeout:[pingInfo timeout]];
		
		[pingInfo release];
	}
}

- (NSString *)sendPingToServer
{
	return [self sendPingToServerWithTimeout:DEFAULT_TIMEOUT];
}

- (NSString *)sendPingToServerWithTimeout:(NSTimeInterval)timeout
{
	NSString *pingID = [self generatePingIDWithTimeout:timeout];
	
	// Send ping packet
	// 
	// <iq type="get" id="pingID">
	//   <ping xmlns="urn:xmpp:ping"/>
	// </iq>
	
	NSXMLElement *ping = [NSXMLElement elementWithName:@"ping" xmlns:@"urn:xmpp:ping"];
	
	XMPPIQ *iq = [XMPPIQ iqWithType:@"get" to:nil elementID:pingID child:ping];
	
	[xmppStream sendElement:iq];
	
	return pingID;
}

- (NSString *)sendPingToJID:(XMPPJID *)jid
{
	return [self sendPingToJID:jid withTimeout:DEFAULT_TIMEOUT];
}

- (NSString *)sendPingToJID:(XMPPJID *)jid withTimeout:(NSTimeInterval)timeout
{
	NSString *pingID = [self generatePingIDWithTimeout:timeout];
	
	// Send ping element
	// 
	// <iq to="fullJID" type="get" id="pingID">
	//   <ping xmlns="urn:xmpp:ping"/>
	// </iq>
	
	NSXMLElement *ping = [NSXMLElement elementWithName:@"ping" xmlns:@"urn:xmpp:ping"];
	
	XMPPIQ *iq = [XMPPIQ iqWithType:@"get" to:jid elementID:pingID child:ping];
	
	[xmppStream sendElement:iq];
	
	return pingID;
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
	NSString *type = [[iq attributeForName:@"type"] stringValue];
	
	if ([type isEqualToString:@"result"] || [type isEqualToString:@"error"])
	{
		// Example:
		// 
		// <iq from="deusty.com" to="robbiehanson@deusty.com/work" id="abc123" type="result"/>
		
		NSString *pingID = [iq elementID];
		
		XMPPPingInfo *pingInfo = [pingIDs objectForKey:pingID];
		if (pingInfo)
		{
			[pingInfo retain];
			[pingIDs removeObjectForKey:pingID];
			
			[multicastDelegate xmppPing:self didReceivePong:iq withRTT:[pingInfo rtt]];
			
			[pingInfo release];
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
			XMPPIQ *pong = [XMPPIQ iqWithType:@"result" to:[iq from] elementID:[iq elementID]];
			
			[sender sendElement:pong];
			
			return YES;
		}
	}
	
	return NO;
}

#if INTEGRATE_WITH_CAPABILITIES
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
#endif

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPPingInfo

@synthesize timeSent;
@synthesize timeout;

- (id)initWithTimeout:(NSTimeInterval)to
{
	if ((self = [super init]))
	{
		timeSent = [[NSDate alloc] init];
		timeout = to;
	}
	return self;
}

- (void)dealloc
{
	[timeSent release];
	[super dealloc];
}

- (NSTimeInterval)rtt
{
	return [timeSent timeIntervalSinceNow] * -1.0;
}

+ (XMPPPingInfo *)pingInfoWithTimeout:(NSTimeInterval)timeout
{
	return [[[XMPPPingInfo alloc] initWithTimeout:timeout] autorelease];
}

@end
