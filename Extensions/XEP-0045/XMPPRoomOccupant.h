#import <Foundation/Foundation.h>

@class XMPPJID;
@class XMPPPresence;


@protocol XMPPRoomOccupant <NSObject>

@property (readonly) XMPPJID *jid;
@property (readonly) NSString *nickname;

@property (readonly) NSString *role;
@property (readonly) NSString *affiliation;

@property (readonly) XMPPPresence *presence;

@end
