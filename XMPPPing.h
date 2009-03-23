#import <Foundation/Foundation.h>

@class XMPPClient;
@class XMPPResource;
@class XMPPIQ;


@interface XMPPPing : NSObject
{
	id delegate;
	
	XMPPClient *client;
	NSMutableArray *pingIDs;
}

- (id)initWithXMPPClient:(XMPPClient *)xmppClient delegate:(id)delegate;

- (XMPPClient *)xmppClient;

- (id)delegate;
- (void)setDelegate:(id)delegate;

- (void)sendPingToServer;
- (void)sendPingToResource:(XMPPResource *)resource;

@end

@interface NSObject (XMPPPingDelegate)

- (void)xmppPing:(XMPPPing *)sender didReceivePong:(XMPPIQ *)pong;

@end
