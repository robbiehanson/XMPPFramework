//
// XMPPRoom
// A chat room. XEP-0045 Implementation.
//

#import <Foundation/Foundation.h>

#import "XMPP.h"
#import "XMPPRoomOccupant.h"

@interface XMPPRoom : NSObject
{
	id delegate;
	XMPPStream *stream;
	NSString *roomName;
	NSString *nickName;
	NSString *subject;
	NSString *invitedUser;
	BOOL isJoined;
	NSMutableDictionary *occupants;
}
@property (nonatomic, readonly, assign) XMPPStream *stream;
@property (nonatomic, readonly, retain) NSString *roomName, *nickName, *subject;
@property (nonatomic, readonly, assign) BOOL isJoined;
@property (nonatomic, readonly) NSMutableDictionary *occupants;


- (id)initWithStream:(XMPPStream *)aStream roomName:(NSString *)name nickName:(NSString *)nickname;

// associated delegate for XMPPRoom Notifications.
- (void)setDelegate:(id)aDelegate;
- (id)delegate;

- (NSString *)invitedUser;
- (void)setInvitedUser:(NSString *)ainvitedUser;

- (void)createOrJoinRoom;
- (void)joinRoom;
- (void)leaveRoom;

- (void)chageNickForRoom:(NSString *)name;

- (void)inviteUser:(XMPPJID *)jid message:(NSString *)message;
- (void)acceptInvitation;
- (void)rejectInvitation;

- (void)sendMessage:(NSString *)msg;

@end

@protocol XMPPRoomDelegate <NSObject>
@optional
- (void)xmppRoom:(XMPPRoom *)room didCreate:(BOOL)success;
- (void)xmppRoom:(XMPPRoom *)room didEnter:(BOOL)enter;
- (void)xmppRoom:(XMPPRoom *)room didLeave:(BOOL)leave;
- (void)xmppRoom:(XMPPRoom *)room didReceiveMessage:(NSString *)message fromNick:(NSString *)nick;
- (void)xmppRoom:(XMPPRoom *)room didChangeOccupants:(NSDictionary *)occupants;

@end
