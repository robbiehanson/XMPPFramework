#import <Foundation/Foundation.h>
#import "XMPPModule.h"

@class XMPPJID;
@class XMPPStream;
@class XMPPIQ;
@protocol XMPPPingDelegate;


@interface XMPPPing : XMPPModule
{
	BOOL respondsToQueries;
	NSMutableDictionary *pingIDs;
}

- (id)initWithStream:(XMPPStream *)xmppStream;
- (id)initWithStream:(XMPPStream *)xmppStream respondsToQueries:(BOOL)flag;

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

@end
