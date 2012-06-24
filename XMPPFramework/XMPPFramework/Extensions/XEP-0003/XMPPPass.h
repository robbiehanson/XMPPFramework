//
//  XMPPPass.h
//  XMPPFramework
//
//  Created by Sean Batson on 12-06-23.
//  Copyright (c) 2012 Baseva, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XMPPModule.h"

#if TARGET_OS_IPHONE
#import "DDXML.h"
#endif

@class XMPPStream;
@class XMPPJID;
@class XMPPIQ;


@interface XMPPPass : XMPPModule
/*
- (id)initWithDispatchQueue:(dispatch_queue_t)queue;
- (void)registrationRequest:(NSString*)serviceName;
- (void)requestToEntity:(XMPPJID*)entityJID;*/
@end

@protocol XMPPPassDelegate
@optional

- (void)xmppPass:(XMPPPass *)sender didReceiveRegistrationSuccess:(XMPPIQ *)iq;
- (void)xmppPass:(XMPPPass *)sender didReceiveRegistrationFailure:(XMPPIQ *)iq;


- (void)xmppPass:(XMPPPass *)sender didReceivePassRequest:(XMPPIQ *)iq;

@end
