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
	dispatch_source_t timer;
}

+ (XMPPPingInfo *)pingInfoWithTimeout:(NSTimeInterval)timeout timer:(dispatch_source_t)timer;

@property (nonatomic, readonly) NSDate *timeSent;
@property (nonatomic, readonly) NSTimeInterval timeout;
@property (nonatomic, readonly) dispatch_source_t timer;

- (NSTimeInterval)rtt;

- (void)cancelTimer;

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
		pingIDs = [[NSMutableDictionary alloc] initWithCapacity:5];
		respondsToQueries = YES;
	}
	return self;
}

- (BOOL)activate:(XMPPStream *)aXmppStream
{
	if ([super activate:aXmppStream])
	{
	#if INTEGRATE_WITH_CAPABILITIES
		[xmppStream autoAddDelegate:self delegateQueue:moduleQueue toModulesOfClass:[XMPPCapabilities class]];
	#endif
		
		return YES;
	}
	
	return NO;
}

- (void)deactivate
{
#if INTEGRATE_WITH_CAPABILITIES
	[xmppStream removeAutoDelegate:self delegateQueue:moduleQueue fromModulesOfClass:[XMPPCapabilities class]];
#endif
	
	dispatch_block_t block = ^{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		for (XMPPPingInfo *pingInfo in [pingIDs objectEnumerator])
		{
			[pingInfo cancelTimer];
		}
		
		[pingIDs removeAllObjects];
		
		[pool drain];
	};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_sync(moduleQueue, block);
	
	[super deactivate];
}

- (void)dealloc
{
	[pingIDs release];
	[super dealloc];
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
			
		#if INTEGRATE_WITH_CAPABILITIES
			// Capabilities may have changed, need to notify others.
			
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			
			XMPPPresence *presence = xmppStream.myPresence;
			if (presence)
			{
				[xmppStream sendElement:presence];
			}
			
			[pool drain];
		#endif
		}
	};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (void)removePingID:(NSString *)pingID
{
	// This method is invoked on the moduleQueue.
	
	XMPPPingInfo *pingInfo = [pingIDs objectForKey:pingID];
	if (pingInfo)
	{
		[pingInfo retain];
		[pingIDs removeObjectForKey:pingID];
		
		[multicastDelegate xmppPing:self didNotReceivePong:pingID dueToTimeout:[pingInfo timeout]];
		
		[pingInfo cancelTimer];
		[pingInfo release];
	}
}

- (NSString *)generatePingIDWithTimeout:(NSTimeInterval)timeout
{
	// This method may be invoked on any thread/queue.
	
	// Generate unique ID for Ping packet
	// It's important the ID be unique as the ID is the only thing that distinguishes a pong packet
	
	NSString *pingID = [xmppStream generateUUID];
	
	dispatch_async(moduleQueue, ^{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		// In case we never get a response, we want to remove the ping ID eventually,
		// or we risk an ever increasing pingIDs array.
		
		dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, moduleQueue);
		
		dispatch_source_set_event_handler(timer, ^{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			
			[self removePingID:pingID];
			
			[pool drain];
		});
		
		dispatch_time_t tt = dispatch_time(DISPATCH_TIME_NOW, (timeout * NSEC_PER_SEC));
		
		dispatch_source_set_timer(timer, tt, DISPATCH_TIME_FOREVER, 0);
		dispatch_resume(timer);
		
		// Add ping ID to list so we'll recognize it when we get a response
		[pingIDs setObject:[XMPPPingInfo pingInfoWithTimeout:timeout timer:timer]
		            forKey:pingID];
		
		dispatch_release(timer);
		[pool release];
	});
	
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

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
	// This method is invoked on the moduleQueue.
	
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
			
			[pingInfo cancelTimer];
			[pingInfo release];
		}
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
	for (XMPPPingInfo *pingInfo in [pingIDs objectEnumerator])
	{
		[pingInfo cancelTimer];
	}
	
	[pingIDs removeAllObjects];
}

#if INTEGRATE_WITH_CAPABILITIES
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
@synthesize timeout;
@synthesize timer;

- (id)initWithTimeout:(NSTimeInterval)to timer:(dispatch_source_t)aTimer
{
	if ((self = [super init]))
	{
		timeSent = [[NSDate alloc] init];
		timeout = to;
		
		timer = aTimer;
		dispatch_retain(timer);
	}
	return self;
}

- (NSTimeInterval)rtt
{
	return [timeSent timeIntervalSinceNow] * -1.0;
}

- (void)cancelTimer
{
	if (timer)
	{
		dispatch_source_cancel(timer);
		dispatch_release(timer);
		timer = NULL;
	}
}

- (void)dealloc
{
	[self cancelTimer];
	[timeSent release];
	[super dealloc];
}


+ (XMPPPingInfo *)pingInfoWithTimeout:(NSTimeInterval)timeout timer:(dispatch_source_t)timer
{
	return [[[XMPPPingInfo alloc] initWithTimeout:timeout timer:timer] autorelease];
}

@end
