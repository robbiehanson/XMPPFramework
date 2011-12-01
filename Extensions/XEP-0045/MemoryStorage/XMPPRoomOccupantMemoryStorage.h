#import <Foundation/Foundation.h>
#import "XMPPRoom.h"
#import "XMPPRoomOccupant.h"


@interface XMPPRoomOccupantMemoryStorage : NSObject <XMPPRoomOccupant, NSCopying, NSCoding>

- (id)initWithPresence:(XMPPPresence *)presence;

@property (readonly) XMPPPresence *presence;

@property (readonly) XMPPJID  * jid;      // [presence from]
@property (readonly) NSString * nickname; // [[presence from] nickname]

@property (readonly) NSString * role;
@property (readonly) NSString * affiliation;
@property (readonly) XMPPJID  * realJID; // Only available in non-anonymous rooms

- (void)updateWithPresence:(XMPPPresence *)presence;

- (NSComparisonResult)compare:(XMPPRoomOccupantMemoryStorage *)another;

@end
