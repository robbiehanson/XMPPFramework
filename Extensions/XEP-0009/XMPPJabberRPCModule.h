//
//  XMPPJabberRPCModule.h
//  XEP-0009
//
//  Originally created by Eric Chamberlain on 5/16/10.
//

#import <Foundation/Foundation.h>
#import "XMPPModule.h"

#define _XMPP_JABBER_RPC_MODULE_H

extern NSString *const XMPPJabberRPCErrorDomain;

@class XMPPJID;
@class XMPPStream;
@class XMPPIQ;
@protocol XMPPJabberRPCModuleDelegate;


@interface XMPPJabberRPCModule : XMPPModule
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


@protocol XMPPJabberRPCModuleDelegate
@optional

// sent when transport error is received
-(void)jabberRPC:(XMPPJabberRPCModule *)sender elementID:(NSString *)elementID didReceiveError:(NSError *)error;

// sent when a methodResponse comes back
-(void)jabberRPC:(XMPPJabberRPCModule *)sender elementID:(NSString *)elementID didReceiveMethodResponse:(id)response;

// sent when a Jabber-RPC server request is received
-(void)jabberRPC:(XMPPJabberRPCModule *)sender didReceiveSetIQ:(XMPPIQ *)iq;
@end
