#import <Foundation/Foundation.h>
#import "XMPPMessage.h"


@interface XMPPMessage(XEP0045)

@property (nonatomic, readonly) BOOL isGroupChatMessage;
@property (nonatomic, readonly) BOOL isGroupChatMessageWithBody;
@property (nonatomic, readonly) BOOL isGroupChatMessageWithSubject;

@end
