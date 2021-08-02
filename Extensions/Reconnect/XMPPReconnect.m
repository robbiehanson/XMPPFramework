#import "XMPPReconnect.h"
#import "XMPPStream.h"
#import "XMPPLogging.h"
#import "NSXMLElement+XMPP.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

#define IMPOSSIBLE_REACHABILITY_FLAGS 0xFFFFFFFF

// Log levels: off, error, warn, info, verbose
#if DEBUG
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#else
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

enum XMPPReconnectFlags
{
	kShouldReconnect        = 1 << 0,  // If set, disconnection was accidental, and autoReconnect may be used
	kShouldRestartReconnect = 1 << 1,  // If set, another reconnection will be attempted after the current one fails
	kManuallyStarted        = 1 << 2,  // If set, we were started manually via manualStart method
	kQueryingDelegates      = 1 << 3,  // If set, we are awaiting response(s) from the delegate(s)
};

enum XMPPReconnectConfig
{
	kAutoReconnect     = 1 << 0,  // If set, automatically attempts to reconnect after a disconnection
};

#if MAC_OS_X_VERSION_MIN_REQUIRED <= MAC_OS_X_VERSION_10_5 && !TARGET_OS_IPHONE
// SCNetworkConnectionFlags was renamed to SCNetworkReachabilityFlags in 10.6
typedef SCNetworkConnectionFlags SCNetworkReachabilityFlags;
#endif

@interface XMPPReconnect() {
    Byte flags;
    Byte config;
    NSTimeInterval reconnectDelay;
    
    dispatch_source_t reconnectTimer;
    NSTimeInterval reconnectTimerInterval;
    
    SCNetworkReachabilityRef reachability;
    
    int reconnectTicket;
    
#if MAC_OS_X_VERSION_MIN_REQUIRED <= MAC_OS_X_VERSION_10_5
    SCNetworkConnectionFlags previousReachabilityFlags;
#else
    SCNetworkReachabilityFlags previousReachabilityFlags;
#endif
}
@end

@interface XMPPReconnect (PrivateAPI)

- (void)setupReconnectTimer;
- (void)teardownReconnectTimer;

- (void)setupNetworkMonitoring;
- (void)teardownNetworkMonitoring;

- (void)maybeAttemptReconnect;
- (void)maybeAttemptReconnectWithTicket:(int)ticket;
- (void)maybeAttemptReconnectWithReachabilityFlags:(SCNetworkReachabilityFlags)reachabilityFlags;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPReconnect

@dynamic    autoReconnect;
@synthesize reconnectDelay;
@synthesize reconnectTimerInterval;

- (id)init
{
	return [self initWithDispatchQueue:NULL];
}

- (id)initWithDispatchQueue:(dispatch_queue_t)queue
{
	if ((self = [super initWithDispatchQueue:queue]))
	{
		flags = 0;
		config = kAutoReconnect;
		
		reconnectDelay = DEFAULT_XMPP_RECONNECT_DELAY;
		reconnectTimerInterval = DEFAULT_XMPP_RECONNECT_TIMER_INTERVAL;
		
		reconnectTicket = 0;
		
		previousReachabilityFlags = IMPOSSIBLE_REACHABILITY_FLAGS;
	}
	return self;
}

- (void)dealloc
{
	dispatch_block_t block = ^{
		[self teardownReconnectTimer];
		[self teardownNetworkMonitoring];
	};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_sync(moduleQueue, block);
	
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Configuration and Flags
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)autoReconnect
{
	__block BOOL result = NO;
	
	dispatch_block_t block = ^{
		result = (self->config & kAutoReconnect) ? YES : NO;
	};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_sync(moduleQueue, block);
	
	return result;
}

- (void)setAutoReconnect:(BOOL)flag
{
	dispatch_block_t block = ^{
		if (flag)
			self->config |= kAutoReconnect;
		else
			self->config &= ~kAutoReconnect;
	};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (BOOL)shouldReconnect
{
	NSAssert(dispatch_get_specific(moduleQueueTag), @"Invoked private method outside moduleQueue");
	
	return (flags & kShouldReconnect) ? YES : NO;
}

- (void)setShouldReconnect:(BOOL)flag
{
	NSAssert(dispatch_get_specific(moduleQueueTag), @"Invoked private method outside moduleQueue");
	
	if (flag)
		flags |= kShouldReconnect;
	else
		flags &= ~kShouldReconnect;
}

- (BOOL)shouldRestartReconnect
{
	NSAssert(dispatch_get_specific(moduleQueueTag), @"Invoked private method outside moduleQueue");
	
	return (flags & kShouldRestartReconnect) ? YES : NO;
}

- (void)setShouldRestartReconnect:(BOOL)flag
{
	NSAssert(dispatch_get_specific(moduleQueueTag), @"Invoked private method outside moduleQueue");
	
	if (flag)
		flags |= kShouldRestartReconnect;
	else
		flags &= ~kShouldRestartReconnect;
}

- (BOOL)manuallyStarted
{
	NSAssert(dispatch_get_specific(moduleQueueTag), @"Invoked private method outside moduleQueue");
	
	return (flags & kManuallyStarted) ? YES : NO;
}

- (void)setManuallyStarted:(BOOL)flag
{
	NSAssert(dispatch_get_specific(moduleQueueTag), @"Invoked private method outside moduleQueue");
	
	if (flag)
		flags |= kManuallyStarted;
	else
		flags &= ~kManuallyStarted;
}

- (BOOL)queryingDelegates
{
	NSAssert(dispatch_get_specific(moduleQueueTag), @"Invoked private method outside moduleQueue");
	
	return (flags & kQueryingDelegates) ? YES : NO;
}

- (void)setQueryingDelegates:(BOOL)flag
{
	NSAssert(dispatch_get_specific(moduleQueueTag), @"Invoked private method outside moduleQueue");
	
	if (flag)
		flags |= kQueryingDelegates;
	else
		flags &= ~kQueryingDelegates;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Manual Manipulation
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)manualStart
{
	dispatch_block_t block = ^{ @autoreleasepool {
		
		if ([self->xmppStream isDisconnected] && [self manuallyStarted] == NO)
		{
			[self setManuallyStarted:YES];
			
			[self setupReconnectTimer];
			[self setupNetworkMonitoring];
		}
	}};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (void)stop
{
	dispatch_block_t block = ^{ @autoreleasepool {
		
		// Clear all flags to disable any further reconnect attemts regardless of the state we're in.
		
		self->flags = 0;
		
		// Stop any planned reconnect attempts and stop monitoring the network.
		
		self->reconnectTicket++;
		
		[self teardownReconnectTimer];
		[self teardownNetworkMonitoring];
		
	}};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStream Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppStreamDidConnect:(XMPPStream *)sender
{
	// This method is executed on our moduleQueue.
	
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
	
	[self setShouldRestartReconnect:NO];
	[self setManuallyStarted:NO];
	
	reconnectTicket++;
	
	[self teardownReconnectTimer];
	[self teardownNetworkMonitoring];
}

- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender
{
	// This method is executed on our moduleQueue.
	
	// We're now connected and properly authenticated.
	// Should we get accidentally disconnected we should automatically reconnect (if autoReconnect is set).
	[self setShouldReconnect:YES];
}

- (void)xmppStream:(XMPPStream *)sender didReceiveError:(NSXMLElement *)element
{
	// This method is executed on our moduleQueue.
	
	// <stream:error>
	//   <conflict xmlns="urn:ietf:params:xml:ns:xmpp-streams"/>
	//   <text xmlns="urn:ietf:params:xml:ns:xmpp-streams" xml:lang="">Replaced by new connection</text>
	// </stream:error>
	// 
	// If our connection ever gets replaced, we shouldn't attempt a reconnect,
	// because the user has logged in on another device.
	// If we still applied the reconnect logic,
	// the two devices may get into an infinite loop of kicking each other off the system.
	
	NSString *elementName = [element name];
	
	if ([elementName isEqualToString:@"stream:error"] || [elementName isEqualToString:@"error"])
	{
		NSXMLElement *conflict = [element elementForName:@"conflict" xmlns:@"urn:ietf:params:xml:ns:xmpp-streams"];
		if (conflict)
		{
			[self setShouldReconnect:NO];
		}
	}
}

- (void)xmppStreamWasToldToDisconnect:(XMPPStream *)sender
{
	// This method is executed on our moduleQueue.
	
	// We should not automatically attempt to reconnect when the connection closes.
	[self stop];
}

- (void)xmppStreamDidDisconnect:(XMPPStream *)sender withError:(NSError *)error
{
	// This method is executed on our moduleQueue.
	
	if ([self autoReconnect] && [self shouldReconnect])
	{
		[self setupReconnectTimer];
		[self setupNetworkMonitoring];
		
		SCNetworkReachabilityFlags reachabilityFlags = 0;
		SCNetworkReachabilityGetFlags(reachability, &reachabilityFlags);
		
		[multicastDelegate xmppReconnect:self didDetectAccidentalDisconnect:reachabilityFlags];
	}
	
	if ([self shouldRestartReconnect])
	{
		// While the previous connection attempt was in progress, the reachability of the xmpp host changed.
		// This means that while the previous attempt failed, an attempt now might succeed.
		
		int ticket = ++reconnectTicket;
		
		dispatch_time_t tt = dispatch_time(DISPATCH_TIME_NOW, (0.1 * NSEC_PER_SEC));
		dispatch_after(tt, moduleQueue, ^{ @autoreleasepool {
			
			[self maybeAttemptReconnectWithTicket:ticket];
			
		}});
		
		// Note: We delay the method call.
		// This allows the other delegates to be notified of the closed stream prior to our reconnect attempt.
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Reachability
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

static void XMPPReconnectReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info)
{
	@autoreleasepool {
	
		XMPPReconnect *instance = (__bridge XMPPReconnect *)info;
        
        if (instance->previousReachabilityFlags != flags) {
            // It's possible that the reachability of our xmpp host has changed in the middle of either
            // a reconnection attempt or while querying our delegates for permission to attempt reconnect.
            
            // In such case it makes sense to abort the current reconnection attempt (if any) instead of waiting for it to time out.
            [instance setShouldRestartReconnect:YES];
        }
        
		[instance maybeAttemptReconnectWithReachabilityFlags:flags];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Logic
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)setupReconnectTimer
{
	NSAssert(dispatch_get_specific(moduleQueueTag) , @"Invoked on incorrect queue");
	
	if (reconnectTimer == NULL)
	{
		if ((reconnectDelay <= 0.0) && (reconnectTimerInterval <= 0.0))
		{
			// All timed reconnect attempts are disabled
			return;
		}
		
		reconnectTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, moduleQueue);
		
		dispatch_source_set_event_handler(reconnectTimer, ^{ @autoreleasepool {
			
            // It is likely that reconnectTimerInterval is shorter than socket's timeout value.
            // In such case we want to abort the current connection attempt (if any) and start a new one.
            [self setShouldRestartReconnect:YES];
            
			[self maybeAttemptReconnect];
			
		}});
		
		#if !OS_OBJECT_USE_OBJC
		dispatch_source_t theReconnectTimer = reconnectTimer;
		
		dispatch_source_set_cancel_handler(reconnectTimer, ^{
			XMPPLogVerbose(@"dispatch_release(reconnectTimer)");
			dispatch_release(theReconnectTimer);
		});
		#endif
		
		dispatch_time_t startTime;
		if (reconnectDelay > 0.0)
			startTime = dispatch_time(DISPATCH_TIME_NOW, (reconnectDelay * NSEC_PER_SEC));
		else
			startTime = dispatch_time(DISPATCH_TIME_NOW, (reconnectTimerInterval * NSEC_PER_SEC));
		
		uint64_t intervalTime;
		if (reconnectTimerInterval > 0.0)
			intervalTime = reconnectTimerInterval * NSEC_PER_SEC;
		else
			intervalTime = 0.0;
		
		dispatch_source_set_timer(reconnectTimer, startTime, intervalTime, 0.25);
		dispatch_resume(reconnectTimer);
	}
}

- (void)teardownReconnectTimer
{
	NSAssert(dispatch_get_specific(moduleQueueTag) , @"Invoked on incorrect queue");
	
	if (reconnectTimer)
	{
		dispatch_source_cancel(reconnectTimer);
		reconnectTimer = NULL;
	}
}

- (void)setupNetworkMonitoring
{
	NSAssert(dispatch_get_specific(moduleQueueTag) , @"Invoked on incorrect queue");
	
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
			SCNetworkReachabilityContext context = {0, (__bridge void *)(self), NULL, NULL, NULL};
			SCNetworkReachabilitySetCallback(reachability, XMPPReconnectReachabilityCallback, &context);
			
			if (moduleQueue)
			{
                SCNetworkReachabilitySetDispatchQueue(reachability,moduleQueue);
			}
			else
			{
                XMPPLogWarn(@"%@: %@ - No xmpp moduleQueue!", THIS_FILE, THIS_METHOD);
			}
		}
	}
}

- (void)teardownNetworkMonitoring
{
	NSAssert(dispatch_get_specific(moduleQueueTag) , @"Invoked on incorrect queue");
	
	if (reachability)
	{
		if (moduleQueue)
		{
            SCNetworkReachabilitySetDispatchQueue(reachability,NULL);
		}
		else
		{
			XMPPLogWarn(@"%@: %@ - No xmpp moduleQueue!", THIS_FILE, THIS_METHOD);
		}
		
		SCNetworkReachabilitySetCallback(reachability, NULL, NULL);
		CFRelease(reachability);
		reachability = NULL;
	}
}

/**
 * This method may be invoked by the reconnectTimer.
 * 
 * During auto reconnection it is invoked reconnectDelay seconds after an accidental disconnection.
 * After that, it is then invoked every reconnectTimerInterval seconds.
 * 
 * This handles disconnections that were not the result of an internet connectivity issue.
**/
- (void)maybeAttemptReconnect
{
	NSAssert(dispatch_get_specific(moduleQueueTag) , @"Invoked on incorrect queue");
	
	if (reachability)
	{
		SCNetworkReachabilityFlags reachabilityFlags;
		if (SCNetworkReachabilityGetFlags(reachability, &reachabilityFlags))
		{
			[self maybeAttemptReconnectWithReachabilityFlags:reachabilityFlags];
		}
	}
}

/**
 * This method is invoked (after a short delay) if the reachability changed while
 * a reconnection attempt was in progress.
**/
- (void)maybeAttemptReconnectWithTicket:(int)ticket
{
	NSAssert(dispatch_get_specific(moduleQueueTag) , @"Invoked on incorrect queue");
	
	if (ticket != reconnectTicket)
	{
		// The dispatched task was cancelled.
		return;
	}
	
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
	if (!dispatch_get_specific(moduleQueueTag))
	{
		dispatch_async(moduleQueue, ^{ @autoreleasepool {
			
			[self maybeAttemptReconnectWithReachabilityFlags:reachabilityFlags];
			
		}});
		
		return;
	}
	
	if (([self manuallyStarted]) || ([self autoReconnect] && [self shouldReconnect])) 
	{
		if ([xmppStream isDisconnected] && ([self queryingDelegates] == NO))
		{
			// The xmpp stream is disconnected, and is not attempting reconnection
			
			// Delegate rules:
			// 
			// If ALL of the delegates return YES, then the result is YES.
			// If ANY of the delegates return NO, then the result is NO.
			// If there are no delegates, the default answer is YES.
			
			GCDMulticastDelegateEnumerator *delegateEnumerator = [multicastDelegate delegateEnumerator];
			
			id del;
			dispatch_queue_t dq;
			
			SEL selector = @selector(xmppReconnect:shouldAttemptAutoReconnect:);
			
			NSUInteger delegateCount = [delegateEnumerator countForSelector:selector];
			
			dispatch_semaphore_t delSemaphore = dispatch_semaphore_create(0);
			dispatch_group_t delGroup = dispatch_group_create();
			
			while ([delegateEnumerator getNextDelegate:&del delegateQueue:&dq forSelector:selector])
			{
				dispatch_group_async(delGroup, dq, ^{ @autoreleasepool {
					
					if (![del xmppReconnect:self shouldAttemptAutoReconnect:reachabilityFlags])
					{
						dispatch_semaphore_signal(delSemaphore);
					}
				}});
			}
			
			[self setQueryingDelegates:YES];
			
			dispatch_queue_t concurrentQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
			dispatch_async(concurrentQueue, ^{ @autoreleasepool {
				
				dispatch_group_wait(delGroup, DISPATCH_TIME_FOREVER);
				
				// What was the delegate response?
				
				BOOL shouldAttemptReconnect;
				if (delegateCount == 0)
				{
					shouldAttemptReconnect = YES;
				}
				else
				{
					shouldAttemptReconnect = (dispatch_semaphore_wait(delSemaphore, DISPATCH_TIME_NOW) != 0);
				}
				
				dispatch_async(self->moduleQueue, ^{ @autoreleasepool {
					
					[self setQueryingDelegates:NO];
					
					if (shouldAttemptReconnect)
					{
						[self setShouldRestartReconnect:NO];
						self->previousReachabilityFlags = reachabilityFlags;
						
                        if (self.usesOldSchoolSecureConnect)
                        {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
							[self->xmppStream oldSchoolSecureConnectWithTimeout:XMPPStreamTimeoutNone error:nil];
#pragma clang diagnostic pop
                        }
                        else
                        {
							[self->xmppStream connectWithTimeout:XMPPStreamTimeoutNone error:nil];
                        }
					}
					else if ([self shouldRestartReconnect])
					{
						[self setShouldRestartReconnect:NO];
						self->previousReachabilityFlags = IMPOSSIBLE_REACHABILITY_FLAGS;
						
						[self maybeAttemptReconnect];
					}
					else
					{
						self->previousReachabilityFlags = IMPOSSIBLE_REACHABILITY_FLAGS;
					}
					
				}});
				
				#if !OS_OBJECT_USE_OBJC
				dispatch_release(delSemaphore);
				dispatch_release(delGroup);
				#endif
			}});
			
		}
		else
		{
			// The xmpp stream is already attempting a connection.
			
            if ([self shouldRestartReconnect])
            {
                [xmppStream abortConnecting];
            }
		}
	}
}

@end
