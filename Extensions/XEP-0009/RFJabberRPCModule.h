//
//  RFJabberRPCModule.h
//  XEP-0009
//
//  Originally created by Eric Chamberlain on 5/16/10.
//

#import <Foundation/Foundation.h>
#import "XMPPModule.h"

extern NSString *const RFJabberRPCErrorDomain;

@class XMPPJID;
@class XMPPStream;
@class XMPPIQ;
@protocol RFJabberRPCModuleDelegate;


@interface RFJabberRPCModule : XMPPModule
{
	NSMutableDictionary *rpcIDs;
	NSTimeInterval defaultTimeout;
}

@property (nonatomic, assign) NSTimeInterval defaultTimeout;

- (NSString *)sendRpcIQ:(XMPPIQ *)iq;
- (NSString *)sendRpcIQ:(XMPPIQ *)iq withTimeout:(NSTimeInterval)timeout;

// caller knows best when a request has timed out
// it should remove the rpcID, on timeout.
- (void)timeoutRemoveRpcID:(NSString *)rpcID;

@end


@protocol RFJabberRPCModuleDelegate
@optional

// sent when transport error is received
-(void)jabberRPC:(RFJabberRPCModule *)sender elementID:(NSString *)elementID didReceiveError:(NSError *)error;

// sent when a methodResponse comes back
-(void)jabberRPC:(RFJabberRPCModule *)sender elementID:(NSString *)elementID didReceiveMethodResponse:(id)response;

// sent when a Jabber-RPC server request is received
-(void)jabberRPC:(RFJabberRPCModule *)sender didReceiveSetIQ:(XMPPIQ *)iq;
@end
