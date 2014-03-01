#import "XMPPSystemInputActivityMonitor.h"
#import "XMPP.h"
#import "XMPPLogging.h"
#import "XMPPFramework.h"


#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

#if TARGET_OS_IPHONE
#warning This file does not work on TARGET_OS_IPHONE.
#endif

// Log levels: off, error, warn, info, verbose
#if DEBUG
static const int xmppLogLevel = XMPP_LOG_LEVEL_VERBOSE;
#else
static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

const NSTimeInterval XMPPSystemInputActivityMonitorInactivityTimeIntervalNone = -1;

#define INACTIVITY_TIME_INTERVAL 300.0
#define TIMER_TIME_INTERVAL 1.0

@implementation XMPPSystemInputActivityMonitor

- (id)init
{
	return [self initWithDispatchQueue:NULL];
}

- (id)initWithDispatchQueue:(dispatch_queue_t)queue
{
	if ((self = [super initWithDispatchQueue:queue]))
	{
		inactivityTimeInterval = INACTIVITY_TIME_INTERVAL;
		active = YES;
	}
	return self;
}


- (BOOL)activate:(XMPPStream *)aXmppStream
{
	XMPPLogTrace();
	
	if ([super activate:aXmppStream])
	{
		XMPPLogVerbose(@"%@: Activated", THIS_FILE);

#if !TARGET_OS_IPHONE

		CFTimeInterval secondsSinceLastUserInteraction = CGEventSourceSecondsSinceLastEventType(kCGEventSourceStateHIDSystemState, kCGAnyInputEventType);
		
		NSDate *date = [NSDate dateWithTimeIntervalSinceNow:(secondsSinceLastUserInteraction * -1)];
		[self _setLastActivityDate:date];

        timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, moduleQueue);
        
        if (timer)
        {
    		dispatch_source_set_timer(timer, dispatch_walltime(NULL, 0), (TIMER_TIME_INTERVAL * NSEC_PER_SEC), 0);
    		dispatch_source_set_event_handler(timer, ^{                
                CFTimeInterval secondsSinceLastUserInteraction = CGEventSourceSecondsSinceLastEventType(kCGEventSourceStateHIDSystemState, kCGAnyInputEventType);

				NSDate *date = [NSDate dateWithTimeIntervalSinceNow:(secondsSinceLastUserInteraction * -1)];
				[self _setLastActivityDate:date];
            });
    		dispatch_resume(timer);
        }
#endif
		
		return YES;
	}
	
	return NO;
}

- (void)deactivate
{
	XMPPLogTrace();
    
	if(timer)
	{
	    dispatch_source_cancel(timer);
	    timer = NULL;
	}

	[super deactivate];
}

- (void)dealloc{
	
	if(timer)
	{
	    dispatch_source_cancel(timer);
	    timer = NULL;
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma Internal
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)_setLastActivityDate:(NSDate *)flag{

	dispatch_block_t block = ^{
		lastActivityDate = flag;
				
		if(inactivityTimeInterval > XMPPSystemInputActivityMonitorInactivityTimeIntervalNone)
		{
			if(active && -[lastActivityDate timeIntervalSinceNow] > inactivityTimeInterval)
			{
				active = NO;
				[multicastDelegate xmppSystemInputActivityMonitorDidBecomeInactive:self];				
			}
			else if(!active && -[lastActivityDate timeIntervalSinceNow] < inactivityTimeInterval)
			{
				active = YES;
				[multicastDelegate xmppSystemInputActivityMonitorDidBecomeActive:self];
			}
			
		}else{
			active = YES;
		}

	};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma Properties
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)isActive
{
	__block BOOL result = YES;;
	
	dispatch_block_t block = ^{
		result = active;
	};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_sync(moduleQueue, block);
	
	return result;
}

- (NSDate *)lastActivityDate
{
	__block NSDate *result = nil;;

	dispatch_block_t block = ^{
		result = lastActivityDate;
	};

	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_sync(moduleQueue, block);

	return result;
}

- (NSTimeInterval)inactivityTimeInterval
{
	__block NSTimeInterval result = XMPPSystemInputActivityMonitorInactivityTimeIntervalNone;

	dispatch_block_t block = ^{
		result = inactivityTimeInterval;
	};

	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_sync(moduleQueue, block);

	return result;
}

- (void)setInactivityTimeInterval:(NSTimeInterval)flag
{
	dispatch_block_t block = ^{
	       inactivityTimeInterval = flag;
	};

	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

@end
