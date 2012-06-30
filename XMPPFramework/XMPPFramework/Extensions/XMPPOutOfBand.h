//
//  XMPPOutOfBand.h
//  XMPPFramework
//
//  Created by Sean Batson on 12-06-29.
//  Copyright (c) 2012 Baseva, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "XMPPModule.h"

@class XMPPJID;
@class XMPPStream;
@class XMPPIQ;
@class XMPPMessage;

@interface XMPPOutOfBand : XMPPModule

- (void)sendOOBRequest:(XMPPJID *)tojid withURL:(NSString*)URL withDesc:(NSString*)desc;

@end


@protocol XMPPOutOfBandDelegate
@optional
- (void)xmppOutOfBand:(XMPPOutOfBand *)sender didReceiveMessageWithURL:(XMPPMessage *)message;
- (void)xmppOutOfBand:(XMPPOutOfBand *)sender didReceiveURL:(XMPPIQ *)iq;
- (void)xmppOutOfBand:(XMPPOutOfBand *)sender didResultInError:(XMPPIQ *)iq;
- (void)xmppOutOfBand:(XMPPOutOfBand *)sender didResultInSuccess:(XMPPIQ *)iq;
@end
