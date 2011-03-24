//
// XMPPRoom
// A chat room. XEP-0045 Implementation.
//

#import <Foundation/Foundation.h>

#import "XMPP.h"
#import "XMPPRoomOccupant.h"

@interface XMPPRoom : XMPPModule
{
	NSString *roomName;
	NSString *nickName;
	NSString *subject;
	NSString *invitedUser;
	BOOL _isJoined;
	NSMutableDictionary *occupants;
}

- (id)initWithRoomName:(NSString *)roomName nickName:(NSString *)nickName;
- (id)initWithRoomName:(NSString *)roomName nickName:(NSString *)nickName dispatchQueue:(dispatch_queue_t)queue;

@property (readonly) NSString *roomName;
@property (readonly) NSString *nickName;
@property (readonly) NSString *subject;

@property (readonly, assign) BOOL isJoined;

@property (readonly) NSDictionary *occupants;

@property (readwrite, copy) NSString *invitedUser;

- (void)createOrJoinRoom;
- (void)joinRoom;
- (void)leaveRoom;

- (void)chageNickForRoom:(NSString *)name;

- (void)inviteUser:(XMPPJID *)jid withMessage:(NSString *)invitationMessage;
- (void)acceptInvitation;
- (void)rejectInvitation;
- (void)rejectInvitationWithMessage:(NSString *)reasonForRejection;

- (void)sendMessage:(NSString *)msg;

@end

@protocol XMPPRoomDelegate <NSObject>
@optional

- (void)xmppRoomDidCreate:(XMPPRoom *)sender;
- (void)xmppRoomDidEnter:(XMPPRoom *)sender;
- (void)xmppRoomDidLeave:(XMPPRoom *)sender;
- (void)xmppRoom:(XMPPRoom *)sender didReceiveMessage:(XMPPMessage *)message fromNick:(NSString *)nick;
- (void)xmppRoom:(XMPPRoom *)sender didChangeOccupants:(NSDictionary *)occupants;

@end
