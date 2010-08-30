#import "XMPPReconnect.h"
#import "XMPPStream.h"

#define IMPOSSIBLE_REACHABILITY_FLAGS 0xFFFFFFFF

enum XMPPReconnectFlags
{
	kAutoReconnect   = 1 << 0,  // If set, automatically attempts to reconnect after a disconnection
	kShouldReconnect = 1 << 1,  // If set, disconnection was accidental, and autoReconnect may be used
	kMultipleChanges = 1 << 2,  // If set, there have been reachability changes during a connection attempt
	kManuallyStarted = 1 << 3,  // If set, we were started manually via manualStart method
};

#if MAC_OS_X_VERSION_MIN_REQUIRED <= MAC_OS_X_VERSION_10_5
// SCNetworkConnectionFlags was renamed to SCNetworkReachabilityFlags in 10.6
typedef SCNetworkConnectionFlags SCNetworkReachabilityFlags;
#endif

@interface XMPPReconnect (PrivateAPI)

- (void)setupReconnectTimer;
- (void)teardownReconnectTimer;

- (void)setupNetworkMonitoring;
- (void)teardownNetworkMonitoring;

- (void)maybeAttemptReconnect:(NSTimer *)timer;
- (void)maybeAttemptReconnectWithReachabilityFlags:(SCNetworkReachabilityFlags)reachabilityFlags;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPReconnect

@synthesize xmppStream;
@dynamic    autoReconnect;
@synthesize reconnectDelay;
@synthesize reconnectTimerInterval;

- (id)initWithStream:(XMPPStream *)aXmppStream
{
	if ((self = [super init]))
	{
		xmppStream = [aXmppStream retain];
		[xmppStream addDelegate:self];
		
		multicastDelegate = [[MulticastDelegate alloc] init];
		
		flags = kAutoReconnect;
		
		reconnectDelay = DEFAULT_XMPP_RECONNECT_DELAY;
		reconnectTimerInterval = DEFAULT_XMPP_RECONNECT_TIMER_INTERVAL;
		
		previousReachabilityFlags = IMPOSSIBLE_REACHABILITY_FLAGS;
	}
	return self;
}

- (void)dealloc
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	
	[xmppStream removeDelegate:self];
	[xmppStream release];
	
	[multicastDelegate release];
	
	[self teardownReconnectTimer];
	[self teardownNetworkMonitoring];
	
	[super dealloc];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Configuration and Flags
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)addDelegate:(id)delegate
{
	[multicastDelegate addDelegate:delegate];
}

- (void)removeDelegate:(id)delegate
{
	[multicastDelegate removeDelegate:delegate];
}

- (BOOL)autoReconnect
{
	return (flags & kAutoReconnect) ? YES : NO;
}

- (void)setAutoReconnect:(BOOL)flag
{
	if(flag)
		flags |= kAutoReconnect;
	else
		flags &= ~kAutoReconnect;
}

- (BOOL)shouldReconnect
{
	return (flags & kShouldReconnect) ? YES : NO;
}

- (void)setShouldReconnect:(BOOL)flag
{
	if(flag)
		flags |= kShouldReconnect;
	else
		flags &= ~kShouldReconnect;
}

- (BOOL)multipleReachabilityChanges
{
	return (flags & kMultipleChanges) ? YES : NO;
}

- (void)setMultipleReachabilityChanges:(BOOL)flag
{
	if(flag)
		flags |= kMultipleChanges;
	else
		flags &= ~kMultipleChanges;
}

- (BOOL)manuallyStarted
{
	return (flags & kManuallyStarted) ? YES : NO;
}

- (void)setManuallyStarted:(BOOL)flag
{
	if(flag)
		flags |= kManuallyStarted;
	else
		flags &= ~kManuallyStarted;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Manual Manipulation
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)manualStart
{
	if ([xmppStream isDisconnected] && [self manuallyStarted] == NO)
	{
		[self setManuallyStarted:YES];
		
		[self setupReconnectTimer];
		[self setupNetworkMonitoring];
	}
}

- (void)stop
{
	// Clear all flags (except the kAutoReconnect flag, which should remain as is)
	// This is to disable any further reconnect attemts regardless of the state we're in.
	
	flags &= kAutoReconnect;
	
	// Stop any planned reconnect attempts and stop monitoring the network.
	
	[NSObject cancelPreviousPerformRequestsWithTarget:self
	                                         selector:@selector(maybeAttemptReconnect:)
	                                           object:nil];
	[self teardownReconnectTimer];
	[self teardownNetworkMonitoring];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStream Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppStreamDidConnect:(XMPPStream *)sender
{
	// The stream is up so we can stop our reconnect attempts now.
	// 
	// We essentially want to do the same thing as the stop method with one exception:
	// We do not want to clear the shouldReconnect flag.
	// 
	// Remember the shouldReconnect flag gets set upon authentication.
	// A combination of this flag and the autoReconnect flag controls the auto reconnect mechanism.
	// 
	// It is possible for us to get accidentally disconnected after
	// the stream opens but prior to authentication completing.
	// If this happens we still want to abide by the previous shouldReconnect setting.
	
	[self setMultipleReachabilityChanges:NO];
	[self setManuallyStarted:NO];
	
	[NSObject cancelPreviousPerformRequestsWithTarget:self
	                                         selector:@selector(maybeAttemptReconnect:)
	                                           object:nil];
	[self teardownReconnectTimer];
	[self teardownNetworkMonitoring];
}

- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender
{
	// We're now connected and properly authenticated.
	// Should we get accidentally disconnected we should automatically reconnect (if autoReconnect is set).
	[self setShouldReconnect:YES];
}

- (void)xmppStreamWasToldToDisconnect:(XMPPStream *)sender
{
	// We should not automatically attempt to reconnect when the connection closes.
	[self stop];
}

- (void)xmppStreamDidDisconnect:(XMPPStream *)sender
{
	if ([self autoReconnect] && [self shouldReconnect])
	{
		[self setupReconnectTimer];
		[self setupNetworkMonitoring];
		
		SCNetworkReachabilityFlags reachabilityFlags = 0;
		SCNetworkReachabilityGetFlags(reachability, &reachabilityFlags);
		
		[multicastDelegate xmppReconnect:self didDetectAccidentalDisconnect:reachabilityFlags];
	}
	
	if ([self multipleReachabilityChanges])
	{
		// While the previous connection attempt was in progress, the reachability of the xmpp host changed.
		// This means that while the previous attempt failed, an attempt now might succeed.
		
		[self performSelector:@selector(maybeAttemptReconnect:)
		           withObject:nil
		           afterDelay:0.0];
		
		// Note: We delay the method call until the next runloop cycle.
		// This allows the other delegates to be notified of the closed stream prior to our reconnect attempt.
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Reachability
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

static void ReachabilityChanged(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info)
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	XMPPReconnect *instance = (XMPPReconnect *)info;
	[instance maybeAttemptReconnectWithReachabilityFlags:flags];
	
	[pool release];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Logic
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)setupReconnectTimer
{
	if (reconnectTimer == nil)
	{
		if ((reconnectDelay <= 0.0) && (reconnectTimerInterval <= 0.0))
		{
			// All timed reconnect attempts are disabled
			return;
		}
		
		NSDate *fireDate;
		if (reconnectDelay > 0.0)
			fireDate = [NSDate dateWithTimeIntervalSinceNow:reconnectDelay];
		else
			fireDate = [NSDate dateWithTimeIntervalSinceNow:reconnectTimerInterval];
		
		BOOL repeats = (reconnectTimerInterval > 0.0);
		
		reconnectTimer = [[NSTimer alloc] initWithFireDate:fireDate
												  interval:reconnectTimerInterval
													target:self
												  selector:@selector(maybeAttemptReconnect:)
												  userInfo:nil
												   repeats:repeats];
		
		[[NSRunLoop currentRunLoop] addTimer:reconnectTimer forMode:NSDefaultRunLoopMode];
	}
}

- (void)teardownReconnectTimer
{
	if (reconnectTimer)
	{
		[reconnectTimer invalidate];
		[reconnectTimer release];
		reconnectTimer = nil;
	}
}

- (void)setupNetworkMonitoring
{
	if (reachability == NULL)
	{
		NSString *domain = xmppStream.hostName;
		if (domain == nil)
		{
			domain = @"apple.com";
		}
		
		reachability = SCNetworkReachabilityCreateWithName(kCFAllocatorDefault, [domain UTF8String]);
		
		if (reachability)
		{
			SCNetworkReachabilityContext context = {0, self, NULL, NULL, NULL};
			SCNetworkReachabilitySetCallback(reachability, ReachabilityChanged, &context);
			
			SCNetworkReachabilityScheduleWithRunLoop(reachability, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
		}
	}
}

- (void)teardownNetworkMonitoring
{
	if (reachability)
	{
		SCNetworkReachabilityUnscheduleFromRunLoop(reachability, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
		CFRelease(reachability);
		reachability = NULL;
	}
}

/**
 * This method may be invoked after a disconnection from the server.
 * 
 * During auto reconnection it is invoked reconnectDelay seconds after an accidental disconnection.
 * After that, it is then invoked reconnectTimerInterval seconds.
 * 
 * This handles disconnections that were not the result of an internet connectivity issue.
 * 
 * It may also be invoked if the reachability changed while a reconnection attempt was in progress.
**/
- (void)maybeAttemptReconnect:(NSTimer *)timer
{
	if (reachability)
	{
		SCNetworkReachabilityFlags reachabilityFlags;
		if (SCNetworkReachabilityGetFlags(reachability, &reachabilityFlags))
		{
			[self maybeAttemptReconnectWithReachabilityFlags:reachabilityFlags];
		}
	}
}

- (void)maybeAttemptReconnectWithReachabilityFlags:(SCNetworkReachabilityFlags)reachabilityFlags
{
	if (([self manuallyStarted]) || ([self autoReconnect] && [self shouldReconnect])) 
	{
		if ([xmppStream isDisconnected])
		{
			// The xmpp stream is disconnected, and is not attempting reconnection
			
			// Delegate rules:
			// 
			// If ALL of the delegates return YES, then the result is YES.
			// If ANY of the delegates return NO, then the result is NO.
			// If there are no delegates, the default answer is YES.
			
			BOOL shouldAttemptReconnect = YES;
			SEL selector = @selector(xmppReconnect:shouldAttemptAutoReconnect:);
			
			MulticastDelegateEnumerator *delegateEnumerator = [multicastDelegate delegateEnumerator];
			id delegate;
			
			while (shouldAttemptReconnect && (delegate = [delegateEnumerator nextDelegateForSelector:selector]))
			{
                shouldAttemptReconnect = [delegate xmppReconnect:self shouldAttemptAutoReconnect:reachabilityFlags];
			}
			
			if (shouldAttemptReconnect)
			{
				[xmppStream connect:nil];
				
				previousReachabilityFlags = reachabilityFlags;
				[self setMultipleReachabilityChanges:NO];
			}
			else
			{
				previousReachabilityFlags = IMPOSSIBLE_REACHABILITY_FLAGS;
				[self setMultipleReachabilityChanges:NO];
			}
		}
		else
		{
			// The xmpp stream is already attempting a connection.
			
			if (reachabilityFlags != previousReachabilityFlags)
			{
				// It seems that the reachability of our xmpp host has changed in the middle of a connection attempt.
				// This may mean that the current attempt will fail,
				// but an another attempt after the failure will succeed.
				// 
				// We make a note of the multiple changes,
				// and if the current attempt fails, we'll try again after a short delay.
				
				[self setMultipleReachabilityChanges:YES];
			}
		}
	}
}

@end
