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

@interface ServerInfo : NSObject
{
    NSString *serverPort;
    NSString *serverName;
}

- (NSString*)serverPort;
- (void)setServerPort:(NSString*)port;

- (NSString*)serverName;
- (void)setServerName:(NSString*)name;

@end

@class XMPPJID;
@class XMPPStream;
@class XMPPIQ;
@class XMPPMessage;


@interface XMPPPass : XMPPModule
{
    NSArray *proxyServer; 
    NSInteger modulestate;
}
+ (NSArray *)proxyServer;
+ (void)setProxyServer:(NSArray *)candidates;

- (void)registrationRequest:(NSString*)serviceName;
- (void)requestToEntity:(XMPPJID*)entityJID;
@end

@protocol XMPPPassDelegate
@optional

- (void)xmppPass:(XMPPPass *)sender didReceiveRegistrationSuccess:(ServerInfo *)srv;
- (void)xmppPass:(XMPPPass *)sender didReceiveRegistrationFailure:(NSError *)reqError;


- (void)xmppPass:(XMPPPass *)sender didReceivePassRequest:(XMPPIQ *)iq;

@end
