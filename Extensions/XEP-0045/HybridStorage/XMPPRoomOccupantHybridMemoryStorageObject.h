#import <Foundation/Foundation.h>
#import "XMPPRoom.h"
#import "XMPPRoomOccupant.h"


@interface XMPPRoomOccupantHybridMemoryStorageObject : NSObject <XMPPRoomOccupant, NSCopying, NSSecureCoding>

- (id)initWithPresence:(XMPPPresence *)presence streamFullJid:(XMPPJID *)streamFullJid;
- (void)updateWithPresence:(XMPPPresence *)presence;

/**
 * The properties below are documented in the XMPPRoomOccupant protocol.
**/

@property (readonly) XMPPPresence *presence;

@property (readonly) XMPPJID  * jid;
@property (readonly) XMPPJID  * roomJID;
@property (readonly) NSString * nickname;

@property (readonly) NSString * role;
@property (readonly) NSString * affiliation;
@property (readonly) XMPPJID  * realJID;

@property (readonly) NSDate * createdAt;

/**
 * Since XMPPRoomHybridStorage supports multiple xmppStreams,
 * this property may be used to differentiate between occupant objects.
**/
@property (readonly) XMPPJID  * streamFullJid;

/**
 * Sample comparison methods.
**/

- (NSComparisonResult)compareByNickname:(XMPPRoomOccupantHybridMemoryStorageObject *)another;

- (NSComparisonResult)compareByCreatedAt:(XMPPRoomOccupantHybridMemoryStorageObject *)another;

@end
