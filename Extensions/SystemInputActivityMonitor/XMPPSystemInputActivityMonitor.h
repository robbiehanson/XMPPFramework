#import "XMPPModule.h"

extern const NSTimeInterval XMPPSystemInputActivityMonitorInactivityTimeIntervalNone;

#define _XMPP_SYSTEM_INPUT_ACTIVITY_MONITOR_H

/**
 * XMPPSystemInputActivityMonitor is used to keep track of system input activity.
 * This module could be used to add features such as "auto away" when the user is inactive for 5 mins.
**/

@interface XMPPSystemInputActivityMonitor : XMPPModule
{    
    dispatch_source_t timer;
	
	BOOL active;
	NSDate *lastActivityDate;
	NSTimeInterval inactivityTimeInterval;
}

/**
 * Returns wether the system is active based on the lastActivityDate and inactivityTimeInterval.
**/
@property (assign, getter = isActive, readonly) BOOL active;

/**
 * The last time any input activity was detected. 
**/
@property (assign, readonly) NSDate *lastActivityDate;

/**
 * The minimum time interval after the last input activity, that assumes the system is idle.
 *
 * To disable activity checking set this value to XMPPSystemInputActivityMonitorInactivityTimeIntervalNone
 * If set to XMPPSystemInputActivityMonitorInactivityTimeIntervalNone none of delegate methods will be called.
 * Setting this value doesn't cause the delegate methods to be called immediately.
 *
 * Default 300 Seconds
**/
@property (assign) NSTimeInterval inactivityTimeInterval;

@end

@protocol XMPPSystemInputActivityMonitorDelegate <NSObject>

/**
 * The system did become active after being inactive.
**/
- (void)xmppSystemInputActivityMonitorDidBecomeActive:(XMPPSystemInputActivityMonitor *)xmppSystemInputActivityMonitor;

/**
 * The system did become inactive after being active.
**/
- (void)xmppSystemInputActivityMonitorDidBecomeInactive:(XMPPSystemInputActivityMonitor *)xmppSystemInputActivityMonitor;

@end