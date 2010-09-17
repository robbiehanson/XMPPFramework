#import <Foundation/Foundation.h>
#import "XMPPModule.h"

@class XMPPJID;
@class XMPPStream;
@class XMPPIQ;
@protocol XMPPPingDelegate;


@interface XMPPPing : XMPPModule
{
	NSMutableArray *pingIDs;
}

- (id)initWithStream:(XMPPStream *)xmppStream;

- (void)sendPingToServer;
- (void)sendPingToJID:(XMPPJID *)jid;

@end

@protocol XMPPPingDelegate
@optional

- (void)xmppPing:(XMPPPing *)sender didReceivePong:(XMPPIQ *)pong;

@end
