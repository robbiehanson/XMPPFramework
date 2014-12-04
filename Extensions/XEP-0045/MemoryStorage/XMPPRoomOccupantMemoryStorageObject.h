#import <Foundation/Foundation.h>
#import "XMPPRoom.h"
#import "XMPPRoomOccupant.h"


@interface XMPPRoomOccupantMemoryStorageObject : NSObject <XMPPRoomOccupant, NSCopying, NSSecureCoding>

- (id)initWithPresence:(XMPPPresence *)presence;
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

/**
 * Compares two occupants based on the nickname.
 * 
 * This method provides the ordering used by XMPPRoomMemoryStorage.
 * Subclasses may override this method to provide an alternative sorting mechanism.
**/
- (NSComparisonResult)compare:(XMPPRoomOccupantMemoryStorageObject *)another;

@end
