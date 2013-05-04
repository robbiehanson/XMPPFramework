#import <Foundation/Foundation.h>
#import "XMPPMessage.h"


@interface XMPPMessage (XEP_0085)

- (NSString *)chatState;

- (BOOL)hasChatState;

- (BOOL)isActiveChatState;
- (BOOL)isComposingChatState;
- (BOOL)isPausedChatState;
- (BOOL)isInactiveChatState;
- (BOOL)isGoneChatState;

- (void)addActiveChatState;
- (void)addComposingChatState;
- (void)addPausedChatState;
- (void)addInactiveChatState;
- (void)addGoneChatState;

@end
