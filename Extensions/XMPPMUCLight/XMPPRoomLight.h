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

@interface XMPPRoomLight : XMPPModule{

	XMPPIDTracker *responseTracker;
	uint16_t state;

}

@property (readonly, nonatomic, strong) XMPPJID *roomJID;
@property (readonly, nonatomic, strong) NSString *domain;
@property (readonly, nonatomic, strong) NSString *roomname;

- (id)initWithDomain:(NSString *)domain;
- (id)initWithJID:(XMPPJID *)jid roomname:(NSString *) roomname;
- (void)createRoomLight:(NSString *)roomName members:(NSArray *) members;
- (void)leaveRoomLight;
- (void)addUsers:(NSArray *)users;
- (void)fetchMembersList;
- (void)sendMessage:(XMPPMessage *)message;
- (void)sendMessageWithBody:(NSString *)messageBody;

@end

@protocol XMPPRoomLightDelegate
@optional

- (void)xmppRoomLight:(XMPPRoomLight *)sender didCreatRoomLight:(XMPPIQ *)iq;
- (void)xmppRoomLight:(XMPPRoomLight *)sender didFailToCreateRoomLight:(XMPPIQ *)iq;

- (void)xmppRoomLight:(XMPPRoomLight *)sender didLeaveRoomLight:(XMPPIQ *)iq;
- (void)xmppRoomLight:(XMPPRoomLight *)sender didFailToLeaveRoomLight:(XMPPIQ *)iq;

- (void)xmppRoomLight:(XMPPRoomLight *)sender didAddUsers:(XMPPIQ*) iqResult;
- (void)xmppRoomLight:(XMPPRoomLight *)sender didFailToAddUsers:(XMPPIQ*)iq;

- (void)xmppRoomLight:(XMPPRoomLight *)sender didFetchMembersList:(NSArray *)items;
- (void)xmppRoomLight:(XMPPRoomLight *)sender didFailToFetchMembersList:(XMPPIQ *)iq;

@end

