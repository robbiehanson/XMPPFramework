#import <Foundation/Foundation.h>

@class XMPPIQ;
@class XMPPJID;
@class XMPPStream;
@import CocoaAsyncSocket;
@protocol TURNSocketDelegate;

/**
 * TURNSocket is an implementation of XEP-0065: SOCKS5 Bytestreams.
 *
 * It is used for establishing an out-of-band bytestream between any two XMPP users,
 * mainly for the purpose of file transfer.
**/
NS_ASSUME_NONNULL_BEGIN
@interface TURNSocket : NSObject <GCDAsyncSocketDelegate>

+ (BOOL)isNewStartTURNRequest:(XMPPIQ *)iq;

@property (class, atomic) NSArray<NSString*> *proxyCandidates;

- (instancetype)initWithStream:(XMPPStream *)xmppStream toJID:(XMPPJID *)jid;
- (instancetype)initWithStream:(XMPPStream *)xmppStream incomingTURNRequest:(XMPPIQ *)iq;

- (void)startWithDelegate:(id<TURNSocketDelegate>)aDelegate delegateQueue:(dispatch_queue_t)aDelegateQueue;

- (BOOL)isClient;

- (void)abort;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol TURNSocketDelegate
@optional

- (void)turnSocket:(TURNSocket *)sender didSucceed:(GCDAsyncSocket *)socket;

- (void)turnSocketDidFail:(TURNSocket *)sender;

@end

NS_ASSUME_NONNULL_END
