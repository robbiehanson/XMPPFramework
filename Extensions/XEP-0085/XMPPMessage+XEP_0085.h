#import <Foundation/Foundation.h>
#import "XMPPMessage.h"


@interface XMPPMessage (XEP_0085)

@property (nonatomic, readonly, nullable) NSString *chatState;

@property (nonatomic, readonly) BOOL hasChatState;

@property (nonatomic, readonly) BOOL hasActiveChatState;
@property (nonatomic, readonly) BOOL hasComposingChatState;
@property (nonatomic, readonly) BOOL hasPausedChatState;
@property (nonatomic, readonly) BOOL hasInactiveChatState;
@property (nonatomic, readonly) BOOL hasGoneChatState;

- (void)addActiveChatState;
- (void)addComposingChatState;
- (void)addPausedChatState;
- (void)addInactiveChatState;
- (void)addGoneChatState;

@end
