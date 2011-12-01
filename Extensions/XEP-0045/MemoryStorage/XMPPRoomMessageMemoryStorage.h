#import <Foundation/Foundation.h>
#import "XMPPRoomMessage.h"


@interface XMPPRoomMessageMemoryStorage : NSObject <XMPPRoomMessage, NSCopying, NSCoding>

- (id)initWithMessage:(XMPPMessage *)message;

@property (nonatomic, readonly) XMPPMessage *message;

@property (nonatomic, readonly) XMPPJID  * jid;
@property (nonatomic, readonly) NSString * nickname;

@property (nonatomic, readonly) NSDate   * timestamp;

- (NSComparisonResult)compare:(XMPPRoomMessageMemoryStorage *)another;

@end
