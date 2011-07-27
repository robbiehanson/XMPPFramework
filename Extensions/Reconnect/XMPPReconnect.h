#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import "XMPPModule.h"

#define DEFAULT_XMPP_RECONNECT_DELAY 2.0

#define DEFAULT_XMPP_RECONNECT_TIMER_INTERVAL 20.0


@protocol XMPPReconnectDelegate;

/**
 * XMPPReconnect handles automatically reconnecting to the xmpp server due to accidental disconnections.
 * That is, a disconnection that is not the result of calling disconnect on the xmpp stream.
 * 
 * Accidental disconnections may happen for a variety of reasons.
 * The most common are general connectivity issues such as disconnection from a WiFi access point.
 * 
 * However, there are several of issues that occasionaly occur.
 * There are some routers on the market that disconnect TCP streams after a period of inactivity.
 * In addition to this, there have been iPhone revisions where the OS networking stack would pull the same crap.
 * These issue have been largely overcome due to the keepalive implementation in XMPPStream.
 * 
 * Regardless of how the disconnect happens, the XMPPReconnect class can help to automatically re-establish
 * the xmpp stream so as to have minimum impact on the user (and hopefully they don't even notice).
 * 
 * Once a stream has been opened and authenticated, this class will detect any accidental disconnections.
 * If one occurs, an attempt will be made to automatically reconnect after a short delay.
 * This delay is configurable via the reconnectDelay property.
 * At the same time the class will begin monitoring the network for reachability changes.
 * When the reachability of the xmpp host has changed, a reconnect may be tried again.
 * In addition to all this, a timer may optionally be used to attempt a reconnect periodically.
 * The timer is started if the initial reconnect fails.
 * This reconnect timer is fully configurable (may be enabled/disabled, and it's timeout may be changed).
 * 
 * In all cases, prior to attempting a reconnect,
 * this class will invoke the shouldAttemptAutoReconnect delegate method.
 * The delegate may use this opportunity to optionally decline the auto reconnect attempt.
 * 
 * Auto reconnect may be disabled at any time via the autoReconnect property.
 * 
 * Note that auto reconnect will only occur for a stream that has been opened and authenticated.
 * So it will do nothing, for example, if there is no internet connectivity when your application
 * first launches, and the xmpp stream is unable to connect to the host.
 * In cases such as this it may be desireable to start monitoring the network for reachability changes.
 * This way when internet connectivity is restored, one can immediately connect the xmpp stream.
 * This is possible via the manualStart method,
 * which will trigger the class into action just as if an accidental disconnect occurred.
**/

@interface XMPPReconnect : XMPPModule
{
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

/**
 * Whether auto reconnect is enabled or disabled.
 * 
 * The default value is YES (enabled).
 * 
 * Note: Altering this property will only affect future accidental disconnections.
 * For example, if autoReconnect was true, and you disable this property after an accidental disconnection,
 * this will not stop the current reconnect process.
 * In order to stop a current reconnect process use the stop method.
 * 
 * Similarly, if autoReconnect was false, and you enable this property after an accidental disconnection,
 * this will not start a reconnect process.
 * In order to start a reconnect process use the manualStart method.
**/
@property (nonatomic, assign) BOOL autoReconnect;

/**
 * When the accidental disconnection first happens,
 * a short delay may be used before attempting the reconnection.
 * 
 * The default value is DEFAULT_XMPP_RECONNECT_DELAY (defined at the top of this file).
 * 
 * To disable this feature, set the value to zero.
 * 
 * Note: NSTimeInterval is a double that specifies the time in seconds.
**/
@property (nonatomic, assign) NSTimeInterval reconnectDelay;

/**
 * A reconnect timer may optionally be used to attempt a reconnect periodically.
 * The timer will be started after the initial reconnect delay.
 * 
 * The default value is DEFAULT_XMPP_RECONNECT_TIMER_INTERVAL (defined at the top of this file).
 * 
 * To disable this feature, set the value to zero.
 * 
 * Note: NSTimeInterval is a double that specifies the time in seconds.
**/
@property (nonatomic, assign) NSTimeInterval reconnectTimerInterval;

/**
 * As opposed to using autoReconnect, this method may be used to manually start the reconnect process.
 * This may be useful, for example, if one needs network monitoring in order to setup the inital xmpp connection.
 * Or if one wants autoReconnect but only in very limited situations which they prefer to control manually.
 * 
 * After invoking this method one can expect the class to act as if an accidental disconnect just occurred.
 * That is, a reconnect attempt will be tried after reconnectDelay seconds,
 * and the class will begin monitoring the network for changes in reachability to the xmpp host.
 * 
 * A manual start of the reconnect process will effectively end once the xmpp stream has been opened.
 * That is, if you invoke manualStart and the xmpp stream is later opened,
 * then future disconnections will not result in an auto reconnect process (unless the autoReconnect property applies).
 * 
 * This method does nothing if the xmpp stream is not disconnected.
**/
- (void)manualStart;

/**
 * Stops the current reconnect process.
 * 
 * This method will stop the current reconnect process regardless of whether the
 * reconnect process was started due to the autoReconnect property or due to a call to manualStart.
 * 
 * Stopping the reconnect process does NOT prevent future auto reconnects if the property is enabled.
 * That is, if the autoReconnect property is still enabled, and the xmpp stream is later opened, authenticated and
 * accidentally disconnected, this class will still attempt an automatic reconnect.
 * 
 * Stopping the reconnect process does NOT prevent future calls to manualStart from working.
 * 
 * It only stops the CURRENT reconnect process.
**/
- (void)stop;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol XMPPReconnectDelegate
@optional

/**
 * This method may be used to fine tune when we
 * should and should not attempt an auto reconnect.
 * 
 * For example, if on the iPhone, one may want to prevent auto reconnect when WiFi is not available.
**/
#if MAC_OS_X_VERSION_MIN_REQUIRED <= MAC_OS_X_VERSION_10_5

- (void)xmppReconnect:(XMPPReconnect *)sender didDetectAccidentalDisconnect:(SCNetworkConnectionFlags)connectionFlags;
- (BOOL)xmppReconnect:(XMPPReconnect *)sender shouldAttemptAutoReconnect:(SCNetworkConnectionFlags)connectionFlags;

#else

- (void)xmppReconnect:(XMPPReconnect *)sender didDetectAccidentalDisconnect:(SCNetworkReachabilityFlags)connectionFlags;
- (BOOL)xmppReconnect:(XMPPReconnect *)sender shouldAttemptAutoReconnect:(SCNetworkReachabilityFlags)reachabilityFlags;

#endif

@end
