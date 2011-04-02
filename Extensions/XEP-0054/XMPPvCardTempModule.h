//
//  XMPPvCardTempModule.h
//  XEP-0054 vCard-temp
//
//  Created by Eric Chamberlain on 3/17/11.
//  Copyright 2011 RF.com. All rights reserved.
//


#import <Foundation/Foundation.h>
#import "XMPPModule.h"
#import "XMPPvCardTemp.h"

@class XMPPJID;
@class XMPPStream;
@protocol XMPPvCardTempModuleStorage;


@interface XMPPvCardTempModule : XMPPModule
{
	id <XMPPvCardTempModuleStorage> _moduleStorage;
}


@property(nonatomic, readonly) id <XMPPvCardTempModuleStorage> moduleStorage;

- (id)initWithvCardStorage:(id <XMPPvCardTempModuleStorage>)storage;
- (id)initWithvCardStorage:(id <XMPPvCardTempModuleStorage>)storage dispatchQueue:(dispatch_queue_t)queue;

/*
 * Return the cached vCard for the user or fetch it, if we don't have it.
 */
- (XMPPvCardTemp *)fetchvCardTempForJID:(XMPPJID *)jid;
- (XMPPvCardTemp *)fetchvCardTempForJID:(XMPPJID *)jid useCache:(BOOL)useCache;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol XMPPvCardTempModuleDelegate
@optional

- (void)xmppvCardTempModule:(XMPPvCardTempModule *)vCardTempModule 
        didReceivevCardTemp:(XMPPvCardTemp *)vCardTemp 
                     forJID:(XMPPJID *)jid;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol XMPPvCardTempModuleStorage <NSObject>

/**
 * Configures the storage class, passing it's parent and parent's dispatch queue.
 * 
 * This method is called by the init methods of the XMPPvCardTempModule class.
 * This method is designed to inform the storage class of it's parent
 * and of the dispatch queue the parent will be operating on.
 * 
 * It is strongly recommended the storage class operate on the same queue as it's parent
 * as the majority of the time it will be getting called by the parent.
 * Thus if both are operating on the same queue, the combination can run faster.
 * 
 * This method should return YES if it was configured properly.
 * The parent class is configured to ignore the passed
 * storage class in it's init method if this method returns NO.
**/
- (BOOL)configureWithParent:(XMPPvCardTempModule *)aParent queue:(dispatch_queue_t)queue;

/*
 * Returns a vCardTemp object or nil
 */
- (XMPPvCardTemp *)vCardTempForJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream;

/*
 * Used to set the vCardTemp object when we get it from the XMPP server.
 */
- (void)setvCardTemp:(XMPPvCardTemp *)vCardTemp forJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream;

/*
 * Asks the backend if we should fetch the vCardTemp from the network.
 * This is used so that we don't request the vCardTemp multiple times.
 */
- (BOOL)shouldFetchvCardTempForJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream;

@end
