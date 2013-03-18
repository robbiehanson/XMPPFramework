#import <Foundation/Foundation.h>
#import "XMPP.h"

#define _XMPP_PING_H

@class XMPPIDTracker;


@interface XMPPPing : XMPPModule
{
	BOOL respondsToQueries;
	XMPPIDTracker *pingTracker;
}

/**
 * Whether or not the module should respond to incoming ping queries.
 * It you create multiple instances of this module, only one instance should respond to queries.
 * 
 * It is recommended you set this (if needed) before you activate the module.
 * The default value is YES.
**/
@property (readwrite) BOOL respondsToQueries;

/**
 * Send pings to the server or a specific JID.
 * The disco module may be used to detect if the target supports ping.
 * 
 * The returned string is the pingID (the elementID of the query that was sent).
 * In other words:
 * 
 * SEND: <iq id="<returned_string>" type="get" .../>
 * RECV: <iq id="<returned_string>" type="result" .../>
 * 
 * This may be helpful if you are sending multiple simultaneous pings to the same target.
**/
- (NSString *)sendPingToServer;
- (NSString *)sendPingToServerWithTimeout:(NSTimeInterval)timeout;
- (NSString *)sendPingToJID:(XMPPJID *)jid;
- (NSString *)sendPingToJID:(XMPPJID *)jid withTimeout:(NSTimeInterval)timeout;

@end

@protocol XMPPPingDelegate
@optional

- (void)xmppPing:(XMPPPing *)sender didReceivePong:(XMPPIQ *)pong withRTT:(NSTimeInterval)rtt;
- (void)xmppPing:(XMPPPing *)sender didNotReceivePong:(NSString *)pingID dueToTimeout:(NSTimeInterval)timeout;

// Note: If the xmpp stream is disconnected, no delegate methods will be called, and outstanding pings are forgotten.

@end
