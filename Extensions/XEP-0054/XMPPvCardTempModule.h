//
//  XMPPvCardTempModule.h
//  XEP-0054 vCard-temp
//
//  Created by Eric Chamberlain on 3/17/11.
//  Copyright 2011 RF.com. All rights reserved.
//


#import <Foundation/Foundation.h>
#import "XMPP.h"

@class XMPPvCardTemp;
@class XMPPIDTracker;

#define _XMPP_VCARD_TEMP_MODULE_H

@protocol XMPPvCardTempModuleStorage;

NS_ASSUME_NONNULL_BEGIN
@interface XMPPvCardTempModule : XMPPModule

@property(nonatomic, strong, readonly) id <XMPPvCardTempModuleStorage> xmppvCardTempModuleStorage;
@property(nonatomic, strong, readonly, nullable) XMPPvCardTemp *myvCardTemp;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithDispatchQueue:(nullable dispatch_queue_t)queue NS_UNAVAILABLE;
- (instancetype)initWithvCardStorage:(id <XMPPvCardTempModuleStorage>)storage;
- (instancetype)initWithvCardStorage:(id <XMPPvCardTempModuleStorage>)storage dispatchQueue:(nullable dispatch_queue_t)queue NS_DESIGNATED_INITIALIZER;

/**
 * Fetches the vCardTemp for the given JID if it is not in the storage
**/
- (void)fetchvCardTempForJID:(XMPPJID *)jid;

/**
 * Fetches the vCardTemp for the given JID, optionally ignoring the storage
**/
- (void)fetchvCardTempForJID:(XMPPJID *)jid ignoreStorage:(BOOL)ignoreStorage;

/**
 * Returns the vCardTemp for the given JID, this is the equivalent of calling the vCardTempForJID:xmppStream: on the moduleStorage
 * If there is no vCardTemp in the storage for the given jid and shouldFetch is YES, it will automatically fetch it from the network
**/
- (nullable XMPPvCardTemp *)vCardTempForJID:(XMPPJID *)jid shouldFetch:(BOOL)shouldFetch;

/**
 * Updates myvCard in storage and sends it to the server
**/
- (void)updateMyvCardTemp:(XMPPvCardTemp *)vCardTemp;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol XMPPvCardTempModuleDelegate
@optional

- (void)xmppvCardTempModule:(XMPPvCardTempModule *)vCardTempModule 
        didReceivevCardTemp:(XMPPvCardTemp *)vCardTemp 
                     forJID:(XMPPJID *)jid;

- (void)xmppvCardTempModule:(XMPPvCardTempModule *)vCardTempModule
        failedToFetchvCardForJID:(XMPPJID *)jid
                      error:(nullable NSXMLElement*)error;

- (void)xmppvCardTempModuleDidUpdateMyvCard:(XMPPvCardTempModule *)vCardTempModule;

- (void)xmppvCardTempModule:(XMPPvCardTempModule *)vCardTempModule failedToUpdateMyvCard:(nullable NSXMLElement *)error;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol XMPPvCardTempModuleStorage <NSObject>

/**
 * Configures the storage class, passing its parent and parent's dispatch queue.
 * 
 * This method is called by the init methods of the XMPPvCardTempModule class.
 * This method is designed to inform the storage class of its parent
 * and of the dispatch queue the parent will be operating on.
 * 
 * The storage class may choose to operate on the same queue as its parent,
 * or it may operate on its own internal dispatch queue.
 * 
 * This method should return YES if it was configured properly.
 * The parent class is configured to ignore the passed
 * storage class in its init method if this method returns NO.
**/
- (BOOL)configureWithParent:(XMPPvCardTempModule *)aParent queue:(dispatch_queue_t)queue;

/**
 * Returns a vCardTemp object or nil
**/
- (nullable XMPPvCardTemp *)vCardTempForJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream;

/**
 * Used to set the vCardTemp object when we get it from the XMPP server.
**/
- (void)setvCardTemp:(XMPPvCardTemp *)vCardTemp forJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream;

/**
 * Returns My vCardTemp object or nil
**/
- (nullable XMPPvCardTemp *)myvCardTempForXMPPStream:(XMPPStream *)stream;

/**
 * Asks the backend if we should fetch the vCardTemp from the network.
 * This is used so that we don't request the vCardTemp multiple times.
**/
- (BOOL)shouldFetchvCardTempForJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream;

@end
NS_ASSUME_NONNULL_END

