#import <Foundation/Foundation.h>

@class XMPPIQ;
@class XMPPJID;
@class XMPPStream;
@class AsyncSocket;

/**
 * TURNSocket is an implementation of XEP-0065: SOCKS5 Bytestreams.
 *
 * It is used for establishing an out-of-band bytestream between any two XMPP users,
 * mainly for the purpose of file transfer.
**/
@interface TURNSocket : NSObject
{
	int state;
	BOOL isClient;
	
	XMPPStream *xmppStream;
	XMPPJID *jid;
	NSString *uuid;
	
	id delegate;
	
	NSString *discoUUID;
	NSTimer *discoTimer;
	
	NSArray *proxyCandidates;
	NSUInteger proxyCandidateIndex;
	
	NSMutableArray *candidateJIDs;
	NSUInteger candidateJIDIndex;
	
	NSMutableArray *streamhosts;
	NSUInteger streamhostIndex;
	
	XMPPJID *proxyJID;
	NSString *proxyHost;
	UInt16 proxyPort;
	
	AsyncSocket *asyncSocket;
	
	NSDate *startTime, *finishTime;
}

+ (BOOL)isNewStartTURNRequest:(XMPPIQ *)iq;

- (id)initWithStream:(XMPPStream *)xmppStream toJID:(XMPPJID *)jid;
- (id)initWithStream:(XMPPStream *)xmppStream incomingTURNRequest:(XMPPIQ *)iq;

- (void)start:(id)delegate;

- (BOOL)isClient;

- (void)abort;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol TURNSocketDelegate
@optional

- (void)turnSocket:(TURNSocket *)sender didSucceed:(AsyncSocket *)socket;

- (void)turnSocketDidFail:(TURNSocket *)sender;

@end