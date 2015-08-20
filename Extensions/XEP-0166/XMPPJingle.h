//
//  XMPPJingle.h
//  xfinity-webrtc-sdk
//
//  Created by Ganvir, Manish  on 2/5/15.
//

#ifndef xfinity_webrtc_sdk_XMPPJingle_h
#define xfinity_webrtc_sdk_XMPPJingle_h
#import <Foundation/Foundation.h>
#import "XMPPModule.h"

@protocol XMPPJingleDelegate;

@interface XMPPJingle : XMPPModule
{
    NSString* from;
    NSString* to;
    XMPPStream *myStream;
    NSString *UID;
    NSString *SID;
}

// delegate to post msg, TODO: managing queue for dispatching msgs
@property(nonatomic,assign) id<XMPPJingleDelegate> delegate;

// Set delegate method
- (void)SetDelegate:(id <XMPPJingleDelegate>)appDelegate;

// For Action (type) attribute: "session-accept", "session-info", "session-initiate", "session-terminate"
- (BOOL)sendSessionMsg:(NSString *)type  data:(NSDictionary *)data target:(XMPPJID *)target;

// For Action (type) attribute: "transport-accept", "transport-info", "transport-reject", "transport-replace"
- (BOOL)sendTransportMsg:(NSString *)type data:(NSDictionary *)data target:(XMPPJID *)target;

// For Action (type) attribute: "content-accept", "content-add", "content-modify", "content-reject", "content-remove"
- (BOOL)sendContentMsg:(NSString *)type data:(NSDictionary *)data;

- (NSXMLElement*)getVideoContent:(NSString *)type  data:(NSDictionary *)data target:(XMPPJID *)target;

@end

@protocol XMPPJingleDelegate <NSObject>

// For Action (type) attribute: "session-accept", "session-info", "session-initiate", "session-terminate"
- (void)didReceiveSessionMsg:(NSString *)sid type:(NSString *)type data:(NSDictionary *)data;

// For Action (type) attribute: "transport-accept", "transport-info", "transport-reject", "transport-replace"
- (void)didReceiveTransportMsg:(NSString *)sid type:(NSString *)type data:(NSDictionary *)data;

// For Action (type) attribute: "content-accept", "content-add", "content-modify", "content-reject", "content-remove"
- (void)didReceiveContentMsg:(NSString *)sid type:(NSString *)type data:(NSDictionary *)data;

// For Action (type) attribute: "description-info"
- (void)didReceiveDescriptionMsg:(NSString *)sid type:(NSString *)type data:(NSDictionary *)data;

// In case any error is received
- (void)didReceiveError:(NSString *)sid error:(NSDictionary *)data;

@end

#endif
