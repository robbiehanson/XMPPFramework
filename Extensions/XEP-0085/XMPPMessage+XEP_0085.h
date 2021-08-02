#import <Foundation/Foundation.h>
#import "XMPPMessage.h"

NS_ASSUME_NONNULL_BEGIN
/** XEP-0085: Chat States XMLNS "http://jabber.org/protocol/chatstates" */
extern NSString *const ChatStatesXmlns;

@interface XMPPMessage (XEP_0085)

@property (nonatomic, readonly, nullable) NSString *chatStateValue;
@property (nonatomic, readonly, nullable) NSString *chatState NS_REFINED_FOR_SWIFT DEPRECATED_MSG_ATTRIBUTE("Use chatStateValue to access the raw String value. This property will be removed in a future release.");

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
NS_ASSUME_NONNULL_END
