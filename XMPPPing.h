#import <Foundation/Foundation.h>
#import "MulticastDelegate.h"

@class XMPPJID;
@class XMPPStream;
@class XMPPIQ;
@protocol XMPPPingDelegate;


@interface XMPPPing : NSObject
{
	XMPPStream *xmppStream;
	MulticastDelegate <XMPPPingDelegate> *multicastDelegate;
	
	NSMutableArray *pingIDs;
}

- (id)initWithStream:(XMPPStream *)xmppStream;

@property (nonatomic, readonly) XMPPStream *xmppStream;

- (void)addDelegate:(id)delegate;
- (void)removeDelegate:(id)delegate;

- (void)sendPingToServer;
- (void)sendPingToJID:(XMPPJID *)jid;

@end

@protocol XMPPPingDelegate
@optional

- (void)xmppPing:(XMPPPing *)sender didReceivePong:(XMPPIQ *)pong;

@end
