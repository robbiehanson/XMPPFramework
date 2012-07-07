#import "XMPPAutoTime.h"
#import "XMPP.h"
#import "XMPPLogging.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

/**
 * Does ARC support support GCD objects?
 * It does if the minimum deployment target is iOS 6+ or Mac OS X 10.8+
**/
#if TARGET_OS_IPHONE

  // Compiling for iOS

  #if __IPHONE_OS_VERSION_MIN_REQUIRED >= 60000 // iOS 6.0 or later
    #define NEEDS_DISPATCH_RETAIN_RELEASE 0
  #else                                         // iOS 5.X or earlier
    #define NEEDS_DISPATCH_RETAIN_RELEASE 1
  #endif

#else

  // Compiling for Mac OS X

  #if MAC_OS_X_VERSION_MIN_REQUIRED >= 1080     // Mac OS X 10.8 or later
    #define NEEDS_DISPATCH_RETAIN_RELEASE 0
  #else
    #define NEEDS_DISPATCH_RETAIN_RELEASE 1     // Mac OS X 10.7 or earlier
  #endif

#endif

// Log levels: off, error, warn, info, verbose
// Log flags: trace
#if DEBUG
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN; // | XMPP_LOG_FLAG_TRACE;
#else
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

@interface XMPPAutoTime ()

@property (nonatomic, strong) NSData *lastServerAddress;
@property (nonatomic, strong) NSDate *systemUptimeChecked;

- (void)updateRecalibrationTimer;
- (void)startRecalibrationTimer;
- (void)stopRecalibrationTimer;
@end

#pragma mark -

@implementation XMPPAutoTime

- (id)initWithDispatchQueue:(dispatch_queue_t)queue
{
	if ((self = [super initWithDispatchQueue:queue]))
	{
		recalibrationInterval = (60 * 60 * 24);
		
		lastCalibrationTime = DISPATCH_TIME_FOREVER;
		
		xmppTime = [[XMPPTime alloc] initWithDispatchQueue:queue];
		xmppTime.respondsToQueries = NO;
		
		[xmppTime addDelegate:self delegateQueue:moduleQueue];
	}
	return self;
}

- (BOOL)activate:(XMPPStream *)aXmppStream
{
	if ([super activate:aXmppStream])
	{
		[xmppTime activate:aXmppStream];
		
		self.systemUptimeChecked = [NSDate date];
		systemUptime = [[NSProcessInfo processInfo] systemUptime];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
		                                         selector:@selector(systemClockDidChange:)
		                                             name:NSSystemClockDidChangeNotification
		                                           object:nil];
		
		return YES;
	}
	
	return NO;
}

- (void)deactivate
{
	dispatch_block_t block = ^{ @autoreleasepool {
		
		[self stopRecalibrationTimer];
		
		[xmppTime deactivate];
		awaitingQueryResponse = NO;
		
		[[NSNotificationCenter defaultCenter] removeObserver:self];
		
		[super deactivate];
	}};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_sync(moduleQueue, block);
}

- (void)dealloc
{
	// recalibrationTimer released in [self deactivate]
	
	[xmppTime removeDelegate:self];
	xmppTime = nil; // Might be referenced via [super dealloc] -> [self deactivate]
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Properties
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@synthesize lastServerAddress;
@synthesize systemUptimeChecked;

- (NSTimeInterval)recalibrationInterval
{
	if (dispatch_get_current_queue() == moduleQueue)
	{
		return recalibrationInterval;
	}
	else
	{
		__block NSTimeInterval result;
		
		dispatch_sync(moduleQueue, ^{
			result = recalibrationInterval;
		});
		return result;
	}
}

- (void)setRecalibrationInterval:(NSTimeInterval)interval
{
	dispatch_block_t block = ^{
		
		if (recalibrationInterval != interval)
		{
			recalibrationInterval = interval;
			
			// Update the recalibrationTimer.
			// 
			// Depending on new value and current state of the recalibrationTimer,
			// this may mean starting, stoping, or simply updating the timer.
			
			if (recalibrationInterval > 0)
			{
				// Remember: Only start the timer after the xmpp stream is up and authenticated
				if ([xmppStream isAuthenticated])
					[self startRecalibrationTimer];
			}
			else
			{
				[self stopRecalibrationTimer];
			}
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
		}
	};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (NSTimeInterval)timeDifference
{
	if (dispatch_get_current_queue() == moduleQueue)
	{
		return timeDifference;
	}
	else
	{
		__block NSTimeInterval result;
		
		dispatch_sync(moduleQueue, ^{
			result = timeDifference;
		});
		
		return result;
	}
}

- (dispatch_time_t)lastCalibrationTime
{
	if (dispatch_get_current_queue() == moduleQueue)
	{
		return lastCalibrationTime;
	}
	else
	{
		__block dispatch_time_t result;
	
		dispatch_sync(moduleQueue, ^{
			result = lastCalibrationTime;
		});
		
		return result;
	}
}

- (BOOL)respondsToQueries
{
	return xmppTime.respondsToQueries;
}

- (void)setRespondsToQueries:(BOOL)respondsToQueries
{
	xmppTime.respondsToQueries = respondsToQueries;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Notifications
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)systemClockDidChange:(NSNotification *)notification
{
	XMPPLogTrace();
	XMPPLogVerbose(@"NSSystemClockDidChangeNotification: %@", notification);
	
	if (lastCalibrationTime == DISPATCH_TIME_FOREVER)
	{
		// Doesn't matter, we haven't done a calibration yet.
		return;
	}
	
	// When the system clock changes, this affects our timeDifference.
	// However, the notification doesn't tell us by how much the system clock has changed.
	// So here's how we figure it out:
	// 
	// The systemUptime isn't affected by the system clock.
	// We previously recorded the system uptime, and simultaneously recoded the system clock time.
	// We can now grab the current system uptime and current system clock time.
	// Using the four data points we can calculate how much the system clock has changed.
	
	NSDate *now = [NSDate date];
	NSTimeInterval sysUptime = [[NSProcessInfo processInfo] systemUptime];
	
	dispatch_async(moduleQueue, ^{ @autoreleasepool {
		
		// Calculate system clock change
		
		NSDate *oldSysTime = systemUptimeChecked;
		NSDate *newSysTime = now;
		
		NSTimeInterval oldSysUptime = systemUptime;
		NSTimeInterval newSysUptime = sysUptime;
		
		NSTimeInterval sysTimeDiff = [newSysTime timeIntervalSinceDate:oldSysTime];
		NSTimeInterval sysUptimeDiff = newSysUptime - oldSysUptime;
		
		NSTimeInterval sysClockChange = sysTimeDiff - sysUptimeDiff;
		
		// Modify timeDifference & notify delegate
		
		timeDifference += sysClockChange;
		[multicastDelegate xmppAutoTime:self didUpdateTimeDifference:timeDifference];
		
		// Dont forget to update our variables
		
		self.systemUptimeChecked = now;
		systemUptime = sysUptime;
		
	}});
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Recalibration Timer
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)handleRecalibrationTimerFire
{
	XMPPLogTrace();
	
	if (awaitingQueryResponse) return;
	
	awaitingQueryResponse = YES;
	
	if (targetJID)
		[xmppTime sendQueryToJID:targetJID];
	else
		[xmppTime sendQueryToServer];
}

- (void)updateRecalibrationTimer
{
	XMPPLogTrace();
	
	NSAssert(recalibrationTimer != NULL, @"Broken logic (1)");
	NSAssert(recalibrationInterval > 0, @"Broken logic (2)");
	
	
	uint64_t interval = (recalibrationInterval * NSEC_PER_SEC);
	dispatch_time_t tt;
	
	if (lastCalibrationTime == DISPATCH_TIME_FOREVER)
		tt = dispatch_time(DISPATCH_TIME_NOW, 0);          // First timer fire at (NOW)
	else
		tt = dispatch_time(lastCalibrationTime, interval); // First timer fire at (lastCalibrationTime + interval)
	
	dispatch_source_set_timer(recalibrationTimer, tt, interval, 0);
}

- (void)startRecalibrationTimer
{
	XMPPLogTrace();
	
	if (recalibrationInterval <= 0)
	{
		// Timer is disabled
		return;
	}
	
	BOOL newTimer = NO;
	
	if (recalibrationTimer == NULL)
	{
		newTimer = YES;
		recalibrationTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, moduleQueue);
		
		dispatch_source_set_event_handler(recalibrationTimer, ^{ @autoreleasepool {
			
			[self handleRecalibrationTimerFire];
			
		}});
	}
	
	[self updateRecalibrationTimer];
	
	if (newTimer)
	{
		dispatch_resume(recalibrationTimer);
	}
}

- (void)stopRecalibrationTimer
{
	XMPPLogTrace();
	
	if (recalibrationTimer)
	{
		#if NEEDS_DISPATCH_RETAIN_RELEASE
		dispatch_release(recalibrationTimer);
		#endif
		recalibrationTimer = NULL;
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPTime Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppTime:(XMPPTime *)sender didReceiveResponse:(XMPPIQ *)iq withRTT:(NSTimeInterval)rtt
{
	XMPPLogTrace();
	
	awaitingQueryResponse = NO;
	
	lastCalibrationTime = dispatch_time(DISPATCH_TIME_NOW, 0);
	timeDifference = [XMPPTime approximateTimeDifferenceFromResponse:iq andRTT:rtt];
		
	[multicastDelegate xmppAutoTime:self didUpdateTimeDifference:timeDifference];
}

- (void)xmppTime:(XMPPTime *)sender didNotReceiveResponse:(NSString *)queryID dueToTimeout:(NSTimeInterval)timeout
{
	XMPPLogTrace();
	
	awaitingQueryResponse = NO;
	
	// Nothing to do here really. Most likely the server doesn't support XEP-0202.
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStream Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppStream:(XMPPStream *)sender socketDidConnect:(GCDAsyncSocket *)socket
{
	NSData *currentServerAddress = [socket connectedAddress];
	
	if (lastServerAddress == nil)
	{
		self.lastServerAddress = currentServerAddress;
	}
	else if (![lastServerAddress isEqualToData:currentServerAddress])
	{
		XMPPLogInfo(@"%@: Connected to a different server. Resetting calibration info.", [self class]);
		
		lastCalibrationTime = DISPATCH_TIME_FOREVER;
		timeDifference = 0.0;
		
		self.lastServerAddress = currentServerAddress;
	}
}

- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender
{
	[self startRecalibrationTimer];
}

- (void)xmppStreamDidDisconnect:(XMPPStream *)sender withError:(NSError *)error
{
	[self stopRecalibrationTimer];
	
	awaitingQueryResponse = NO;
	
	// We do NOT reset the lastCalibrationTime here.
	// If we reconnect to the same server, the lastCalibrationTime remains valid.
}

@end
