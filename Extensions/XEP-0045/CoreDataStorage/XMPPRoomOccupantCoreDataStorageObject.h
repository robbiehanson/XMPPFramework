#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

#import "XMPP.h"
#import "XMPPRoom.h"


@interface XMPPRoomOccupantCoreDataStorageObject : NSManagedObject <XMPPRoomOccupant>

/**
 * The properties below are documented in the XMPPRoomOccupant protocol.
**/

@property (nonatomic, strong) XMPPPresence * presence; // Transient (proper type, not on disk) 
@property (nonatomic, strong) NSString * presenceStr;  // Shadow (binary data, written to disk)

@property (nonatomic, strong) XMPPJID * roomJID;       // Transient (proper type, not on disk)
@property (nonatomic, strong) NSString * roomJIDStr;   // Shadow (binary data, written to disk)

@property (nonatomic, strong) XMPPJID * jid;           // Transient (proper type, not on disk)
@property (nonatomic, strong) NSString * jidStr;       // Shadow (binary data, written to disk)

@property (nonatomic, strong) NSString * nickname;

@property (nonatomic, strong) NSString * role;
@property (nonatomic, strong) NSString * affiliation;

@property (nonatomic, strong) XMPPJID * realJID;       // Transient (proper type, not on disk)
@property (nonatomic, strong) NSString * realJIDStr;   // Shadow (binary data, written to disk)

@property (nonatomic, strong) NSDate * createdAt;

/**
 * If a single instance of XMPPRoomCoreDataStorage is shared between multiple xmppStream's,
 * this may be needed to distinguish between the streams.
**/
@property (nonatomic, strong) NSString * streamBareJidStr;

@end
