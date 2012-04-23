#import <Foundation/Foundation.h>
#import "XMPPModule.h"
#import "XMPPPing.h"

#define _XMPP_AUTO_PING_H

@class XMPPJID;


/**
 * The XMPPAutoPing module sends pings on a designated interval to the target.
 * The target may simply be the server, or a specific resource.
 * 
 * The module only sends pings as needed.
 * If the xmpp stream is receiving data from the target, there's no need to send a ping.
 * Only when no data has been received from the target is a ping sent.
**/
@interface XMPPAutoPing : XMPPModule {
@private
	NSTimeInterval pingInterval;
	NSTimeInterval pingTimeout;
	XMPPJID *targetJID;
	NSString *targetJIDStr;
	
	NSTimeInterval lastReceiveTime;
	dispatch_source_t pingIntervalTimer;
	
	BOOL awaitingPingResponse;
	XMPPPing *xmppPing;
}

/**
 * How often to send a ping.
 * 
 * The internal timer fires every (pingInterval / 4) seconds.
 * Upon firing it checks when data was last received from the target,
 * and sends a ping if the elapsed time has exceeded the pingInterval.
 * Thus the effective resolution of the timer is based on the configured interval.
 * 
 * To temporarily disable auto-ping, set the interval to zero.
 * 
 * The default pingInterval is 60 seconds.
**/
@property (readwrite) NSTimeInterval pingInterval;

/**
 * How long to wait after sending a ping before timing out.
 * 
 * The timeout is decoupled from the pingInterval to allow for longer pingIntervals,
 * which avoids flooding the network, and to allow more precise control overall.
 * 
 * After a ping is sent, if a reply is not received by this timeout,
 * the delegate method is invoked.
 * 
 * The default pingTimeout is 10 seconds.
**/
@property (readwrite) NSTimeInterval pingTimeout;

/**
 * The target to send pings to.
 * 
 * If the targetJID is nil, this implies the target is the xmpp server we're connected to.
 * In this case, receiving any data means we've received data from the target.
 * 
 * If the targetJID is non-nil, it must be a full JID (user@domain.tld/rsrc).
 * In this case, the module will monitor the stream for data from the given JID.
 * 
 * The default targetJID is nil.
**/
@property (readwrite, strong) XMPPJID *targetJID;

/**
 * Corresponds to the last time data was received from the target.
 * The NSTimeInterval value comes from [NSDate timeIntervalSinceReferenceDate]
**/
@property (readonly) NSTimeInterval lastReceiveTime;

/**
 * XMPPAutoPing is used to automatically send pings on a regular interval.
 * Sometimes the target is also sending pings to us as well.
 * If so, you may optionally set respondsToQueries to YES to allow the module to respond to incoming pings.
 * 
 * If you create multiple instances of XMPPAutoPing or XMPPPing,
 * then only one instance should respond to queries. 
 * 
 * The default value is NO.
**/
@property (readwrite) BOOL respondsToQueries;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol XMPPAutoPingDelegate
@optional

- (void)xmppAutoPingDidSendPing:(XMPPAutoPing *)sender;
- (void)xmppAutoPingDidReceivePong:(XMPPAutoPing *)sender;

- (void)xmppAutoPingDidTimeout:(XMPPAutoPing *)sender;

@end
