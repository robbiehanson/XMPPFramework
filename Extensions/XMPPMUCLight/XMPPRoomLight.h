//
//  XMPPRoomLight.h
//  Mangosta
//
//  Created by Andres Canal on 5/27/16.
//  Copyright © 2016 Inaka. All rights reserved.
//

#import "XMPP.h"
#import "XMPPIDTracker.h"
#import "XMPPJID.h"

@protocol XMPPRoomLightStorage;

@interface XMPPRoomLight : XMPPModule {

	__strong id <XMPPRoomLightStorage> xmppRoomLightStorage;
	XMPPIDTracker *responseTracker;

}

@property (readonly, nonatomic, strong, nonnull) XMPPJID *roomJID;
@property (readonly, nonatomic, strong, nonnull) NSString *domain;

- (nonnull NSString *)roomname;
- (nonnull NSString *)subject;

- (nonnull instancetype)initWithJID:(nonnull XMPPJID *)roomJID roomname:(nonnull NSString *) roomname;
- (nonnull instancetype)initWithRoomLightStorage:(nullable id <XMPPRoomLightStorage>)storage jid:(nonnull XMPPJID *)aRoomJID roomname:(nonnull NSString *)aRoomname dispatchQueue:(nullable dispatch_queue_t)queue;
- (void)createRoomLightWithMembersJID:(nullable NSArray<XMPPJID *> *) members;
- (void)leaveRoomLight;
- (void)addUsers:(nonnull NSArray<XMPPJID *> *)users;
- (void)fetchMembersList;
- (void)sendMessage:(nonnull XMPPMessage *)message;
- (void)sendMessageWithBody:(nonnull NSString *)messageBody;
- (void)changeRoomSubject:(nonnull NSString *)roomSubject;
- (void)destroyRoom;
- (void)changeAffiliations:(nonnull NSArray<NSXMLElement *> *)members;
- (void)getConfiguration;
- (void)setConfiguration:(nonnull NSArray<NSXMLElement *> *)configs;
- (void)flushVersion;
@end

@protocol XMPPRoomLightStorage <NSObject>
@required

- (void)handleIncomingMessage:(nonnull XMPPMessage *)message room:(nonnull XMPPRoomLight *)room;
- (void)handleOutgoingMessage:(nonnull XMPPMessage *)message room:(nonnull XMPPRoomLight *)room;

@end

@protocol XMPPRoomLightDelegate
@optional

- (void)xmppRoomLight:(nonnull XMPPRoomLight *)sender didReceiveMessage:(nonnull XMPPMessage *)message;

- (void)xmppRoomLight:(nonnull XMPPRoomLight *)sender didCreateRoomLight:(nonnull XMPPIQ *)iq;
- (void)xmppRoomLight:(nonnull XMPPRoomLight *)sender didFailToCreateRoomLight:(nonnull XMPPIQ *)iq;

- (void)xmppRoomLight:(nonnull XMPPRoomLight *)sender didLeaveRoomLight:(nonnull XMPPIQ *)iq;
- (void)xmppRoomLight:(nonnull XMPPRoomLight *)sender didFailToLeaveRoomLight:(nonnull XMPPIQ *)iq;

- (void)xmppRoomLight:(nonnull XMPPRoomLight *)sender didAddUsers:(nonnull XMPPIQ*) iqResult;
- (void)xmppRoomLight:(nonnull XMPPRoomLight *)sender didFailToAddUsers:(nonnull XMPPIQ*)iq;

- (void)xmppRoomLight:(nonnull XMPPRoomLight *)sender didFetchMembersList:(nonnull NSArray<NSXMLElement*> *)items;
- (void)xmppRoomLight:(nonnull XMPPRoomLight *)sender didFailToFetchMembersList:(nonnull XMPPIQ *)iq;

- (void)xmppRoomLight:(nonnull XMPPRoomLight *)sender didDestroyRoomLight:(nonnull XMPPIQ*) iqResult;
- (void)xmppRoomLight:(nonnull XMPPRoomLight *)sender didFailToDestroyRoomLight:(nonnull XMPPIQ*)iq;

- (void)xmppRoomLight:(nonnull XMPPRoomLight *)sender didChangeAffiliations:(nonnull XMPPIQ*) iqResult;
- (void)xmppRoomLight:(nonnull XMPPRoomLight *)sender didFailToChangeAffiliations:(nonnull XMPPIQ*)iq;

- (void)xmppRoomLight:(nonnull XMPPRoomLight *)sender didGetConfiguration:(nonnull XMPPIQ*) iqResult;
- (void)xmppRoomLight:(nonnull XMPPRoomLight *)sender didFailToGetConfiguration:(nonnull XMPPIQ*)iq;

- (void)xmppRoomLight:(nonnull XMPPRoomLight *)sender didSetConfiguration:(nonnull XMPPIQ*) iqResult;
- (void)xmppRoomLight:(nonnull XMPPRoomLight *)sender didFailToSetConfiguration:(nonnull XMPPIQ*)iq;

- (void)xmppRoomLight:(nonnull XMPPRoomLight *)sender roomDestroyed:(nonnull XMPPMessage *)message;
- (void)xmppRoomLight:(nonnull XMPPRoomLight *)sender configurationChanged:(nonnull XMPPMessage *)message;

@end

