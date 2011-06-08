//
// XMPPRoomOccupant
// A chat room. XEP-0045 Implementation.
//

#import <Foundation/Foundation.h>

@class XMPPJID;

@interface XMPPRoomOccupant : NSObject
{
	XMPPJID *jid;
	NSString *nick;
	NSString *role;
}

+ (XMPPRoomOccupant *)occupantWithJID:(XMPPJID *)aJid nick:(NSString *)aNick role:(NSString *)aRole;

- (id)initWithJID:(XMPPJID *)aJid nick:(NSString *)aNick role:(NSString *)aRole;

@property (readonly) XMPPJID *jid;
@property (readonly) NSString *nick;
@property (readonly) NSString *role;

@end
