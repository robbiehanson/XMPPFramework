#import <Foundation/Foundation.h>

@class XMPPJID;
@class XMPPMessage;


@protocol XMPPRoomMessage <NSObject>

/**
 * The raw message that was sent / received.
**/
- (XMPPMessage *)message;

/**
 * The JID of the MUC room.
**/
- (XMPPJID *)roomJID;

/**
 * Who sent the message.
 * A typical MUC room jid is of the form "room_name@conference.domain.tld/some_nickname".
**/
- (XMPPJID *)jid;

/**
 * The nickname of the user who sent the message.
 * This is a convenience method for [jid resource].
**/
- (NSString *)nickname;

/**
 * Convenience method to access the body of the message.
**/
- (NSString *)body;

/**
 * When the message was sent / received (as recorded by us).
 * 
 * If the message was originally sent by us, the localTimestamp is recorded automatically.
 * If the message was received, the server may have included a delayed delivery date timestamp.
 * This is the case when first joining a room, and downloading the discussion history.
 * In such a case, the localTimestamp will be a reflection of the serverTimestamp.
**/
- (NSDate *)localTimestamp;

/**
 * When the message was sent / received (as recorded by the server).
 * 
 * Only set when the server includes a delayedDelivery timestamp within the message.
**/
- (NSDate *)remoteTimestamp;

/**
 * Whether or not the message was sent by us.
**/
- (BOOL)isFromMe;

@end
