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

@property (weak, readonly) XMPPJID *jid;
@property (weak, readonly) NSString *nick;
@property (weak, readonly) NSString *role;

@end
