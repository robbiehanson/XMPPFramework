//
//  XMPPRoomLight.h
//  Mangosta
//
//  Created by Andres Canal on 5/27/16.
//  Copyright © 2016 Inaka. All rights reserved.
//

#import <XMPPFramework/XMPPFramework.h>
#import <XMPPFramework/XMPPIDTracker.h>
#import <XMPPFramework/XMPPJID.h>

@protocol XMPPRoomLightStorage;

@interface XMPPRoomLight : XMPPModule {

	__strong id <XMPPRoomLightStorage> xmppRoomLightStorage;
	XMPPIDTracker *responseTracker;

}

@property (readonly, nonatomic, strong, nonnull) XMPPJID *roomJID;
@property (readonly, nonatomic, strong, nonnull) NSString *domain;
@property (readonly, nonatomic, strong, nonnull) NSString *roomname;


- (nonnull instancetype)initWithJID:(nonnull XMPPJID *)roomJID roomname:(nonnull NSString *) roomname;
- (nonnull instancetype)initWithRoomLightStorage:(nullable id <XMPPRoomLightStorage>)storage jid:(nonnull XMPPJID *)aRoomJID roomname:(nonnull NSString *)roomname dispatchQueue:(nullable dispatch_queue_t)queue;
- (void)createRoomLightWithMembersJID:(nullable NSArray<XMPPJID *> *) members;
- (void)leaveRoomLight;
- (void)addUsers:(nonnull NSArray<XMPPJID *> *)users;
- (void)fetchMembersList;
- (void)sendMessage:(nonnull XMPPMessage *)message;
- (void)sendMessageWithBody:(nonnull NSString *)messageBody;

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

@end

