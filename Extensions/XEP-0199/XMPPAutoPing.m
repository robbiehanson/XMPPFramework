#import "XMPPAutoPing.h"
#import "XMPPPing.h"
#import "XMPP.h"
#import "XMPPLogging.h"

// Log levels: off, error, warn, info, verbose
// Log flags: trace
static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN; // | XMPP_LOG_FLAG_TRACE;

@interface XMPPAutoPing ()
- (void)updatePingIntervalTimer;
- (void)stopPingIntervalTimer;
@end

#pragma mark -

@implementation XMPPAutoPing

- (id)init
{
	return [self initWithDispatchQueue:NULL];
}

- (id)initWithDispatchQueue:(dispatch_queue_t)queue
{
	if ((self = [super initWithDispatchQueue:queue]))
	{
		pingInterval = 60;
		pingTimeout = 10;
		
		lastReceiveTime = DISPATCH_TIME_FOREVER;
		
		xmppPing = [[XMPPPing alloc] initWithDispatchQueue:queue];
		[xmppPing addDelegate:self delegateQueue:moduleQueue];
	}
	return self;
}

- (BOOL)activate:(XMPPStream *)aXmppStream
{
	if ([super activate:aXmppStream])
	{
		[xmppPing activate:aXmppStream];
		
		return YES;
	}
	
	return NO;
}

- (void)deactivate
{
	dispatch_block_t block = ^{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		[self stopPingIntervalTimer];
		
		[xmppPing deactivate];
		
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
	[targetJID release];
	[targetJIDStr release];
	
	[self stopPingIntervalTimer];
	
	[xmppPing removeDelegate:self];
	[xmppPing release];
	
	[super dealloc];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Properties
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSTimeInterval)pingInterval
{
	if (dispatch_get_current_queue() == moduleQueue)
	{
		return pingInterval;
	}
	else
	{
		__block NSTimeInterval result;
		
		dispatch_sync(moduleQueue, ^{
			result = pingInterval;
		});
		return result;
	}
}

- (void)setPingInterval:(NSTimeInterval)interval
{
	dispatch_block_t block = ^{
		
		if (pingInterval != interval)
		{
			pingInterval = interval;
			
			[self updatePingIntervalTimer];
		}
	};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (NSTimeInterval)pingTimeout
{
	if (dispatch_get_current_queue() == moduleQueue)
	{
		return pingTimeout;
	}
	else
	{
		__block NSTimeInterval result;
		
		dispatch_sync(moduleQueue, ^{
			result = pingTimeout;
		});
		return result;
	}
}

- (void)setPingTimeout:(NSTimeInterval)timeout
{
	dispatch_block_t block = ^{
		
		if (pingTimeout != timeout)
		{
			pingTimeout = timeout;
		}
	};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (XMPPJID *)targetJID
{
	if (dispatch_get_current_queue() == moduleQueue)
	{
		return targetJID;
	}
	else
	{
		__block XMPPJID *result;
		
		dispatch_sync(moduleQueue, ^{
			result = [targetJID retain];
		});
		return [result autorelease];
	}
}

- (void)setTargetJID:(XMPPJID *)jid
{
	dispatch_block_t block = ^{
		
		if (![targetJID isEqual:jid])
		{
			[targetJID release];
			targetJID = [jid retain];
			
			[targetJIDStr release];
			targetJIDStr = [[targetJID full] retain];
		}
	};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (dispatch_time_t)lastReceiveTime
{
	if (dispatch_get_current_queue() == moduleQueue)
	{
		return lastReceiveTime;
	}
	else
	{
		__block dispatch_time_t result;
		
		dispatch_sync(moduleQueue, ^{
			result = lastReceiveTime;
		});
		return result;
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Ping Interval
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)handlePingIntervalTimerFire
{
	dispatch_time_t now = dispatch_time(DISPATCH_TIME_NOW, 0);
	NSTimeInterval elapsed = ((now - lastReceiveTime) / NSEC_PER_SEC);
	
	if (elapsed >= pingInterval)
	{
		if (targetJID)
			[xmppPing sendPingToJID:targetJID withTimeout:pingTimeout];
		else
			[xmppPing sendPingToServerWithTimeout:pingTimeout];
	}
}

- (void)updatePingIntervalTimer
{
	if (pingIntervalTimer && [xmppStream isAuthenticated])
	{
		uint64_t interval = (pingInterval * NSEC_PER_SEC);
		dispatch_time_t tt = dispatch_time(DISPATCH_TIME_NOW, interval);
		
		dispatch_source_set_timer(pingIntervalTimer, tt, interval, 0);
	}
}

- (void)startPingIntervalTimer
{
	BOOL newTimer = NO;
	
	if (pingIntervalTimer == NULL)
	{
		newTimer = YES;
		pingIntervalTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, moduleQueue);
		
		dispatch_source_set_event_handler(pingIntervalTimer, ^{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			
			[self handlePingIntervalTimerFire];
			
			[pool drain];
		});
	}
	
	[self updatePingIntervalTimer];
	
	if (newTimer)
	{
		dispatch_resume(pingIntervalTimer);
	}
}

- (void)stopPingIntervalTimer
{
	if (pingIntervalTimer)
	{
		dispatch_release(pingIntervalTimer);
		pingIntervalTimer = NULL;
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPPing Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppPing:(XMPPPing *)sender didReceivePong:(XMPPIQ *)pong withRTT:(NSTimeInterval)rtt
{
	XMPPLogTrace();
}

- (void)xmppPing:(XMPPPing *)sender didNotReceivePong:(NSString *)pingID dueToTimeout:(NSTimeInterval)timeout
{
	XMPPLogTrace();
	
	[multicastDelegate xmppAutoPingDidTimeout:self];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStream Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender
{
	[self startPingIntervalTimer];
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
	if (targetJID == nil || [targetJIDStr isEqualToString:[iq fromStr]])
	{
		lastReceiveTime = dispatch_time(DISPATCH_TIME_NOW, 0);
	}
	
	return NO;
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
	if (targetJID == nil || [targetJIDStr isEqualToString:[message fromStr]])
	{
		lastReceiveTime = dispatch_time(DISPATCH_TIME_NOW, 0);
	}
}

- (void)xmppStream:(XMPPStream *)sender didReceivePresence:(XMPPPresence *)presence
{
	if (targetJID == nil || [targetJIDStr isEqualToString:[presence fromStr]])
	{
		lastReceiveTime = dispatch_time(DISPATCH_TIME_NOW, 0);
	}
}

- (void)xmppStreamDidDisconnect:(XMPPStream *)sender withError:(NSError *)error
{
	[self stopPingIntervalTimer];
	
	lastReceiveTime = DISPATCH_TIME_FOREVER;
}

@end
