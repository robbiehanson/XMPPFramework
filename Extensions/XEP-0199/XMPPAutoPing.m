#import "XMPPAutoPing.h"
#import "XMPPPing.h"
#import "XMPP.h"
#import "XMPPLogging.h"

// Log levels: off, error, warn, info, verbose
// Log flags: trace
#if DEBUG
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN | XMPP_LOG_FLAG_TRACE;
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
		
		lastReceiveTime = DISPATCH_TIME_FOREVER;
		
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
	dispatch_block_t block = ^{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		[self stopPingIntervalTimer];
		
		lastReceiveTime = DISPATCH_TIME_FOREVER;
		awaitingPingResponse = NO;
		
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
			
			// Update the pingTimer.
			// Depending on new value this may mean starting, stoping, or simply updating the timer.
			
			if (pingIntervalTimer)
			{
				if (pingInterval > 0)
				{
					// Remember: Only start the pinger after the xmpp stream is up and authenticated
					if ([xmppStream isAuthenticated])
						[self updatePingIntervalTimer];
				}
				else
				{
					[self stopPingIntervalTimer];
				}
			}
			else if (pingInterval > 0)
			{
				[self startPingIntervalTimer];
			}
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
	if (awaitingPingResponse) return;
	
	BOOL sendPing = NO;
	
	if (lastReceiveTime == DISPATCH_TIME_FOREVER)
	{
		sendPing = YES;
	}
	else
	{
		dispatch_time_t now = dispatch_time(DISPATCH_TIME_NOW, 0);
		NSTimeInterval elapsed = ((double)(now - lastReceiveTime) / (double)NSEC_PER_SEC);
		
		XMPPLogTrace2(@"%@: %@ - elapsed(%f)", [self class], THIS_METHOD, elapsed);
		
		sendPing = (elapsed >= pingInterval);
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
	
	
	uint64_t interval = ((pingInterval / 4.0) * NSEC_PER_SEC);
	dispatch_time_t tt;
	
	if (lastReceiveTime != DISPATCH_TIME_FOREVER)
		tt = dispatch_time(lastReceiveTime, interval);
	else
		tt = dispatch_time(DISPATCH_TIME_NOW, interval);
	
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
	XMPPLogTrace();
	
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
	lastReceiveTime = dispatch_time(DISPATCH_TIME_NOW, 0);
	awaitingPingResponse = NO;
	
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
	awaitingPingResponse = NO;
}

@end
