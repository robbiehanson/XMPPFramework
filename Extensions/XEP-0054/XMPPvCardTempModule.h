//
//  XMPPvCardTempModule.h
//  XEP-0054 vCard-temp
//
//  Created by Eric Chamberlain on 3/17/11.
//  Copyright 2011 RF.com. All rights reserved.
//

#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE
#import "DDXML.h"
#endif

#import "NSXMLElementAdditions.h"
#import "XMPPJID.h"
#import "XMPPModule.h"

#import "XMPPStream.h"
#import "XMPPvCardTemp.h"


@protocol XMPPvCardTempModuleStorage;


@interface XMPPvCardTempModule : XMPPModule {
  id <XMPPvCardTempModuleStorage> _moduleStorage;
}


@property(nonatomic,retain,readonly) id <XMPPvCardTempModuleStorage> moduleStorage;


- (id)initWithStream:(XMPPStream *)xmppStream storage:(id <XMPPvCardTempModuleStorage>)moduleStorage;


/*
 * return the cached vCard for the user or fetch it, if we don't have it.
 */
- (XMPPvCardTemp *)fetchvCardTempForJID:(XMPPJID *)jid xmppStream:(XMPPStream *)xmppStream;
- (XMPPvCardTemp *)fetchvCardTempForJID:(XMPPJID *)jid xmppStream:(XMPPStream *)xmppStream useCache:(BOOL)useCache;


@end


@protocol XMPPvCardTempModuleDelegate


@optional


- (void)xmppvCardTempModule:(XMPPvCardTempModule *)vCardTempModule 
            didReceivevCardTemp:(XMPPvCardTemp *)vCardTemp 
                     forJID:(XMPPJID *)jid
                 xmppStream:(XMPPStream *)xmppStream;


@end


@protocol XMPPvCardTempModuleStorage <NSObject>


/*
 * Returns a vCardTemp object or nil
 */
- (XMPPvCardTemp *)vCardTempForJID:(XMPPJID *)jid;


/*
 * Used to set the vCardTemp object when we get it from the XMPP server.
 */
- (void)setvCardTemp:(XMPPvCardTemp *)vCardTemp forJID:(XMPPJID *)jid;


/*
 * Asks the backend if we should fetch the vCardTemp from the network.
 * This is used so that we don't request the vCardTemp multiple times.
 */
- (BOOL)shouldFetchvCardTempForJID:(XMPPJID *)jid;

@end
