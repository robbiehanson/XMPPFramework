#import <Foundation/Foundation.h>
#import "XMPPMessage.h"


@interface XMPPMessage(XEP0045)

- (BOOL)isGroupChatMessage;
- (BOOL)isGroupChatMessageWithBody;
- (BOOL)isGroupChatMessageWithSubject;

- (NSString *)subject;
- (void)addSubject:(NSString *)subject;

@end
