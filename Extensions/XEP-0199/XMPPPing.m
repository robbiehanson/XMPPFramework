#import "XMPPPing.h"
#import "XMPPIDTracker.h"
#import "XMPPFramework.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

#define DEFAULT_TIMEOUT 30.0 // seconds


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface XMPPPingInfo : XMPPBasicTrackingInfo
{
	NSDate *timeSent;
}

@property (nonatomic, readonly) NSDate *timeSent;

- (NSTimeInterval)rtt;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPPing

- (id)init
{
	return [self initWithDispatchQueue:NULL];
}

- (id)initWithDispatchQueue:(dispatch_queue_t)queue
{
	if ((self = [super initWithDispatchQueue:queue]))
	{
		respondsToQueries = YES;
	}
	return self;
}

- (BOOL)activate:(XMPPStream *)aXmppStream
{
	if ([super activate:aXmppStream])
	{
	#ifdef _XMPP_CAPABILITIES_H
		[xmppStream autoAddDelegate:self delegateQueue:moduleQueue toModulesOfClass:[XMPPCapabilities class]];
	#endif
		
		pingTracker = [[XMPPIDTracker alloc] initWithDispatchQueue:moduleQueue];
		
		return YES;
	}
	
	return NO;
}

- (void)deactivate
{
#ifdef _XMPP_CAPABILITIES_H
	[xmppStream removeAutoDelegate:self delegateQueue:moduleQueue fromModulesOfClass:[XMPPCapabilities class]];
#endif
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		[pingTracker removeAllIDs];
		pingTracker = nil;
		
	}};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_sync(moduleQueue, block);
	
	[super deactivate];
}


- (BOOL)respondsToQueries
{
	if (dispatch_get_current_queue() == moduleQueue)
	{
		return respondsToQueries;
	}
	else
	{
		__block BOOL result;
		
		dispatch_sync(moduleQueue, ^{
			result = respondsToQueries;
		});
		return result;
	}
}

- (void)setRespondsToQueries:(BOOL)flag
{
	dispatch_block_t block = ^{
		
		if (respondsToQueries != flag)
		{
			respondsToQueries = flag;
			
		#ifdef _XMPP_CAPABILITIES_H
			@autoreleasepool {
				// Capabilities may have changed, need to notify others.
				[xmppStream resendMyPresence];
			}
		#endif
		}
	};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (NSString *)generatePingIDWithTimeout:(NSTimeInterval)timeout
{
	// This method may be invoked on any thread/queue.
	
	// Generate unique ID for Ping packet
	// It's important the ID be unique as the ID is the only thing that distinguishes a pong packet
	
	NSString *pingID = [xmppStream generateUUID];
	
	dispatch_async(moduleQueue, ^{ @autoreleasepool {
		
		XMPPPingInfo *pingInfo = [[XMPPPingInfo alloc] initWithTarget:self
		                                                     selector:@selector(handlePong:withInfo:)
		                                                      timeout:timeout];
		
		[pingTracker addID:pingID trackingInfo:pingInfo];
		
	}});
	
	return pingID;
}

- (NSString *)sendPingToServer
{
	// This is a public method.
	// It may be invoked on any thread/queue.
	
	return [self sendPingToServerWithTimeout:DEFAULT_TIMEOUT];
}

- (NSString *)sendPingToServerWithTimeout:(NSTimeInterval)timeout
{
	// This is a public method.
	// It may be invoked on any thread/queue.
	
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
	// This is a public method.
	// It may be invoked on any thread/queue.
	
	return [self sendPingToJID:jid withTimeout:DEFAULT_TIMEOUT];
}

- (NSString *)sendPingToJID:(XMPPJID *)jid withTimeout:(NSTimeInterval)timeout
{
	// This is a public method.
	// It may be invoked on any thread/queue.
	
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

- (void)handlePong:(XMPPIQ *)pongIQ withInfo:(XMPPPingInfo *)pingInfo
{
	if (pongIQ)
	{
		[multicastDelegate xmppPing:self didReceivePong:pongIQ withRTT:[pingInfo rtt]];
	}
	else
	{
		// Timeout
		
		[multicastDelegate xmppPing:self didNotReceivePong:[pingInfo elementID] dueToTimeout:[pingInfo timeout]];
	}
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
	// This method is invoked on the moduleQueue.
	
	NSString *type = [iq type];
	
	if ([type isEqualToString:@"result"] || [type isEqualToString:@"error"])
	{
		// Example:
		// 
		// <iq from="deusty.com" to="robbiehanson@deusty.com/work" id="abc123" type="result"/>
		
		// If this is a response to a ping that we've sent,
		// then the pingTracker will invoke our handlePong:withInfo: method and return YES.
		
		return [pingTracker invokeForID:[iq elementID] withObject:iq];
	}
	else if (respondsToQueries && [type isEqualToString:@"get"])
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

- (void)xmppStreamDidDisconnect:(XMPPStream *)sender withError:(NSError *)error
{
	[pingTracker removeAllIDs];
}

#ifdef _XMPP_CAPABILITIES_H
/**
 * If an XMPPCapabilites instance is used we want to advertise our support for ping.
**/
- (void)xmppCapabilities:(XMPPCapabilities *)sender collectingMyCapabilities:(NSXMLElement *)query
{
	// This method is invoked on the moduleQueue.
	
	if (respondsToQueries)
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
}
#endif

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPPingInfo

@synthesize timeSent;

- (id)initWithTarget:(id)aTarget selector:(SEL)aSelector timeout:(NSTimeInterval)aTimeout
{
	if ((self = [super initWithTarget:aTarget selector:aSelector timeout:aTimeout]))
	{
		timeSent = [[NSDate alloc] init];
	}
	return self;
}

- (NSTimeInterval)rtt
{
	return [timeSent timeIntervalSinceNow] * -1.0;
}


@end
