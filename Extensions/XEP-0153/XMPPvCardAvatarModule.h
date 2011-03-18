//
//  XMPPvCardAvatarModule.h
//  XEP-0153 vCard-Based Avatars
//
//  Created by Eric Chamberlain on 3/9/11.
//  Copyright 2011 RF.com. All rights reserved.

/*
 *  NOTE: Currently this implementation only supports downloading and caching avatars.
 */


#import <Foundation/Foundation.h>

#import "XMPPModule.h"
#import "XMPPStream.h"


@class XMPPJID;
@class XMPPvCardTempModule;


@protocol XMPPvCardAvatarStorage;


@interface XMPPvCardAvatarModule : XMPPModule {
	XMPPvCardTempModule *_xmppvCardTempModule;
  id <XMPPvCardAvatarStorage> _moduleStorage;
}

@property(nonatomic,retain,readonly) XMPPvCardTempModule *xmppvCardTempModule;


- (id)initWithStream:(XMPPStream *)xmppStream 
 xmppvCardTempModule:(XMPPvCardTempModule *)xmppvCardTempModule;


@end


@protocol XMPPvCardAvatarStorage <NSObject>


- (NSString *)photoHashForJID:(XMPPJID *)jid;

- (void)clearvCardTempForJID:(XMPPJID *)jid;


@end