#import <Foundation/Foundation.h>

@class XMPPJID;
@class XMPPPresence;

NS_ASSUME_NONNULL_BEGIN
@protocol XMPPRoomOccupant <NSObject>

/**
 * Most recent presence message from occupant.
**/
@property (nonatomic, readonly) XMPPPresence *presence;

/**
 * The MUC room the occupant is associated with.
**/
@property (nonatomic, readonly) XMPPJID *roomJID;

/**
 * The JID of the occupant as reported by the room.
 * A typical MUC room will use JIDs of the form: "room_name@conference.domain.tl/some_nickname".
**/
@property (nonatomic, readonly) XMPPJID *jid;

/**
 * The nickname of the user.
 * In other words, the resource portion of the occupants JID.
**/
@property (nonatomic, readonly) NSString *nickname;

/**
 * The 'role' and 'affiliation' of the occupant within the MUC room.
 * 
 * From XEP-0045, Section 5 - Roles and Affiliations:
 * 
 * There are two dimensions along which we can measure a user's connection with or position in a room.
 * One is the user's long-lived affiliation with a room -- e.g., a user's status as an owner or an outcast.
 * The other is a user's role while an occupant of a room -- e.g., an occupant's position as a moderator with the
 * ability to kick visitors and participants. These two dimensions are distinct from each other, since an affiliation
 * lasts across visits, while a role lasts only for the duration of a visit. In addition, there is no one-to-one
 * correspondence between roles and affiliations; for example, someone who is not affiliated with a room may be
 * a (temporary) moderator, and a member may be a participant or a visitor in a moderated room.
 * 
 * For more information, please see XEP-0045.
**/
@property (nonatomic, readonly, nullable) NSString *role;
@property (nonatomic, readonly, nullable) NSString *affiliation;

/**
 * If the MUC room is non-anonymous, the real JID of the user will be broadcast.
 * 
 * An anonymous room uses JID's of the form: "room_name@conference.domain.tld/some_nickname".
 * A non-anonymous room also includes the occupants real full JID in the presence broadcast.
**/
@property (nonatomic, readonly, nullable) XMPPJID *realJID;

@end
NS_ASSUME_NONNULL_END
