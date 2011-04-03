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
#import "XMPPvCardTempModule.h"


@class XMPPJID;
@class XMPPStream;


@protocol XMPPvCardAvatarStorage;


@interface XMPPvCardAvatarModule : XMPPModule <XMPPvCardTempModuleDelegate>
{
	XMPPvCardTempModule *_xmppvCardTempModule;
  id <XMPPvCardAvatarStorage> _moduleStorage;
}

@property(nonatomic,retain,readonly) XMPPvCardTempModule *xmppvCardTempModule;


- (id)initWithvCardTempModule:(XMPPvCardTempModule *)xmppvCardTempModule;
- (id)initWithvCardTempModule:(XMPPvCardTempModule *)xmppvCardTempModule  dispatchQueue:(dispatch_queue_t)queue;


- (NSData *)photoDataForJID:(XMPPJID *)jid;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol XMPPvCardAvatarStorage <NSObject>

- (NSData *)photoDataForJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream;
- (NSString *)photoHashForJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream;

/**
 * Clears the vCardTemp from the store.
 * This is used so we can clear any cached vCardTemp's for the JID.
 **/
- (void)clearvCardTempForJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream;

@end