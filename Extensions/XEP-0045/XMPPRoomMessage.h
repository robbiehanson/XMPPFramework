#import <Foundation/Foundation.h>

@class XMPPJID;
@class XMPPMessage;


@protocol XMPPRoomMessage <NSObject>

@property (nonatomic, readonly) XMPPMessage * message;

@property (nonatomic, readonly) XMPPJID  * jid;      // [message from]
@property (nonatomic, readonly) NSString * nickname; // [[message from] resource]

@property (nonatomic, readonly) NSString * body;

@property (nonatomic, readonly) NSDate   * timestamp;

@end
