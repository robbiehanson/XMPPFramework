#import "XMPPAutoPing.h"
#import "XMPPPing.h"
#import "XMPP.h"
#import "XMPPLogging.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

// Log levels: off, error, warn, info, verbose
// Log flags: trace
#if DEBUG
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#else
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

@interface XMPPAutoPing ()
- (void)updatePingIntervalTimer;
- (void)startPingIntervalTimer;
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
		
		lastReceiveTime = 0;
		
		xmppPing = [[XMPPPing alloc] initWithDispatchQueue:queue];
		xmppPing.respondsToQueries = NO;
		
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
	dispatch_block_t block = ^{ @autoreleasepool {
		
		[self stopPingIntervalTimer];
		
		lastReceiveTime = 0;
		awaitingPingResponse = NO;
		
		[xmppPing deactivate];
		[super deactivate];
		
	}};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_sync(moduleQueue, block);
}

- (void)dealloc
{
	
	[self stopPingIntervalTimer];
	
	[xmppPing removeDelegate:self];
	
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Properties
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSTimeInterval)pingInterval
{
	if (dispatch_get_specific(moduleQueueTag))
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
			
			// Update the pingTimer.
			// 
			// Depending on new value and current state of the pingTimer,
			// this may mean starting, stoping, or simply updating the timer.
			
			if (pingInterval > 0)
			{
				// Remember: Only start the pinger after the xmpp stream is up and authenticated
				if ([xmppStream isAuthenticated])
					[self startPingIntervalTimer];
			}
			else
			{
				[self stopPingIntervalTimer];
			}
		}
	};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (NSTimeInterval)pingTimeout
{
	if (dispatch_get_specific(moduleQueueTag))
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
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (XMPPJID *)targetJID
{
	if (dispatch_get_specific(moduleQueueTag))
	{
		return targetJID;
	}
	else
	{
		__block XMPPJID *result;
		
		dispatch_sync(moduleQueue, ^{
			result = targetJID;
		});
		return result;
	}
}

- (void)setTargetJID:(XMPPJID *)jid
{
	dispatch_block_t block = ^{
		
		if (![targetJID isEqualToJID:jid])
		{
			targetJID = jid;
			
			targetJIDStr = [targetJID full];
		}
	};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (NSTimeInterval)lastReceiveTime
{
	if (dispatch_get_specific(moduleQueueTag))
	{
		return lastReceiveTime;
	}
	else
	{
		__block NSTimeInterval result;
		
		dispatch_sync(moduleQueue, ^{
			result = lastReceiveTime;
		});
		return result;
	}
}

- (BOOL)respondsToQueries
{
	return xmppPing.respondsToQueries;
}

- (void)setRespondsToQueries:(BOOL)respondsToQueries
{
	xmppPing.respondsToQueries = respondsToQueries;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Ping Interval
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)handlePingIntervalTimerFire
{
	if (awaitingPingResponse) return;
	
	BOOL sendPing = NO;
	
	if (lastReceiveTime == 0)
	{
		sendPing = YES;
	}
	else
	{
		NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
		NSTimeInterval elapsed = (now - lastReceiveTime);
		
		XMPPLogTrace2(@"%@: %@ - elapsed(%f)", [self class], THIS_METHOD, elapsed);
		
		sendPing = ((elapsed < 0) || (elapsed >= pingInterval));
	}
	
	if (sendPing)
	{
		awaitingPingResponse = YES;
		
		if (targetJID)
			[xmppPing sendPingToJID:targetJID withTimeout:pingTimeout];
		else
			[xmppPing sendPingToServerWithTimeout:pingTimeout];
		
		[multicastDelegate xmppAutoPingDidSendPing:self];
	}
}

- (void)updatePingIntervalTimer
{
	XMPPLogTrace();
	
	NSAssert(pingIntervalTimer != NULL, @"Broken logic (1)");
	NSAssert(pingInterval > 0, @"Broken logic (2)");
	
	// The timer fires every (pingInterval / 4) seconds.
	// Upon firing it checks when data was last received from the target,
	// and sends a ping if the elapsed time has exceeded the pingInterval.
	// Thus the effective resolution of the timer is based on the configured pingInterval.
	
	uint64_t interval = ((pingInterval / 4.0) * NSEC_PER_SEC);
	
	// The timer's first fire should occur 'interval' after lastReceiveTime.
	// If there is no lastReceiveTime, then the timer's first fire should occur 'interval' after now.
	
	NSTimeInterval diff;
	if (lastReceiveTime == 0)
		diff = 0.0;
	else
		diff = lastReceiveTime - [NSDate timeIntervalSinceReferenceDate];;
	
	dispatch_time_t bt = dispatch_time(DISPATCH_TIME_NOW, (diff * NSEC_PER_SEC));
	dispatch_time_t tt = dispatch_time(bt, interval);
	
	dispatch_source_set_timer(pingIntervalTimer, tt, interval, 0);
}

- (void)startPingIntervalTimer
{
	XMPPLogTrace();
	
	if (pingInterval <= 0)
	{
		// Pinger is disabled
		return;
	}
	
	BOOL newTimer = NO;
	
	if (pingIntervalTimer == NULL)
	{
		newTimer = YES;
		pingIntervalTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, moduleQueue);
		
		dispatch_source_set_event_handler(pingIntervalTimer, ^{ @autoreleasepool {
			
			[self handlePingIntervalTimerFire];
			
		}});
	}
	
	[self updatePingIntervalTimer];
	
	if (newTimer)
	{
		dispatch_resume(pingIntervalTimer);
	}
}

- (void)stopPingIntervalTimer
{
	XMPPLogTrace();
	
	if (pingIntervalTimer)
	{
		#if !OS_OBJECT_USE_OBJC
		dispatch_release(pingIntervalTimer);
		#endif
		pingIntervalTimer = NULL;
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPPing Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppPing:(XMPPPing *)sender didReceivePong:(XMPPIQ *)pong withRTT:(NSTimeInterval)rtt
{
	XMPPLogTrace();
	
	awaitingPingResponse = NO;
	[multicastDelegate xmppAutoPingDidReceivePong:self];
}

- (void)xmppPing:(XMPPPing *)sender didNotReceivePong:(NSString *)pingID dueToTimeout:(NSTimeInterval)timeout
{
	XMPPLogTrace();
	
	awaitingPingResponse = NO;
	[multicastDelegate xmppAutoPingDidTimeout:self];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStream Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender
{
	lastReceiveTime = [NSDate timeIntervalSinceReferenceDate];
	awaitingPingResponse = NO;
	
	[self startPingIntervalTimer];
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
	if (targetJID == nil || [targetJIDStr isEqualToString:[iq fromStr]])
	{
		lastReceiveTime = [NSDate timeIntervalSinceReferenceDate];
	}
	
	return NO;
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
	if (targetJID == nil || [targetJIDStr isEqualToString:[message fromStr]])
	{
		lastReceiveTime = [NSDate timeIntervalSinceReferenceDate];
	}
}

- (void)xmppStream:(XMPPStream *)sender didReceivePresence:(XMPPPresence *)presence
{
	if (targetJID == nil || [targetJIDStr isEqualToString:[presence fromStr]])
	{
		lastReceiveTime = [NSDate timeIntervalSinceReferenceDate];
	}
}

- (void)xmppStreamDidDisconnect:(XMPPStream *)sender withError:(NSError *)error
{
	[self stopPingIntervalTimer];
	
	lastReceiveTime = 0;
	awaitingPingResponse = NO;
}

@end
