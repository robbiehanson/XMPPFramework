#import <Foundation/Foundation.h>
#import "XMPPRoomMessage.h"


@interface XMPPRoomMessageMemoryStorageObject : NSObject <XMPPRoomMessage, NSCopying, NSCoding>

- (id)initWithIncomingMessage:(XMPPMessage *)message;
- (id)initWithOutgoingMessage:(XMPPMessage *)message  jid:(XMPPJID *)myRoomJID;

/**
 * The properties below are documented in the XMPPRoomMessage protocol.
**/

@property (nonatomic, readonly) XMPPMessage *message;

@property (nonatomic, readonly) XMPPJID  * roomJID;

@property (nonatomic, readonly) XMPPJID  * jid;
@property (nonatomic, readonly) NSString * nickname;

@property (nonatomic, readonly) NSDate   * localTimestamp;
@property (nonatomic, readonly) NSDate   * remoteTimestamp;

@property (nonatomic, readonly) BOOL isFromMe;

/**
 * Compares two messages based on the localTimestamp.
 * 
 * This method provides the ordering used by XMPPRoomMemoryStorage.
 * Subclasses may override this method to provide an alternative sorting mechanism.
**/
- (NSComparisonResult)compare:(XMPPRoomMessageMemoryStorageObject *)another;

@end
