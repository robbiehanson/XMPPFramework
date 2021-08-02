#import <Foundation/Foundation.h>

@class XMPPJID;
@class XMPPMessage;

NS_ASSUME_NONNULL_BEGIN
@protocol XMPPRoomMessage <NSObject>

/**
 * The raw message that was sent / received.
**/
@property (nonatomic, readonly) XMPPMessage *message;

/**
 * The JID of the MUC room.
**/
@property (nonatomic, readonly) XMPPJID *roomJID;

/**
 * Who sent the message.
 * A typical MUC room jid is of the form "room_name@conference.domain.tld/some_nickname".
**/
@property (nonatomic, readonly) XMPPJID *jid;

/**
 * The nickname of the user who sent the message.
 * This is a convenience method for [jid resource].
**/
@property (nonatomic, readonly) NSString *nickname;

/**
 * Convenience method to access the body of the message.
**/
@property (nonatomic, readonly) NSString *body;

/**
 * When the message was sent / received (as recorded by us).
 * 
 * If the message was originally sent by us, the localTimestamp is recorded automatically.
 * If the message was received, the server may have included a delayed delivery date timestamp.
 * This is the case when first joining a room, and downloading the discussion history.
 * In such a case, the localTimestamp will be a reflection of the serverTimestamp.
**/
@property (nonatomic, readonly) NSDate *localTimestamp;

/**
 * When the message was sent / received (as recorded by the server).
 * 
 * Only set when the server includes a delayedDelivery timestamp within the message.
**/
@property (nonatomic, readonly, nullable) NSDate *remoteTimestamp;

/**
 * Whether or not the message was sent by us.
**/
@property (nonatomic, readonly) BOOL isFromMe;

@end
NS_ASSUME_NONNULL_END
