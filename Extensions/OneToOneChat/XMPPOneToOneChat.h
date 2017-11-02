#import "XMPPModule.h"

NS_ASSUME_NONNULL_BEGIN

@class XMPPMessage;

/// @brief A module that handles one-to-one chat messaging.
/// @discussion This module triggers delegate callbacks for all sent or received messages of type 'chat'.
@interface XMPPOneToOneChat : XMPPModule

@end

/// A protocol defining @c XMPPOneToOneChat module delegate API.
@protocol XMPPOneToOneChatDelegate <NSObject>

@optional
/// Notifies the delegate that a chat message has been received in the stream.
- (void)xmppOneToOneChat:(XMPPOneToOneChat *)xmppOneToOneChat didReceiveChatMessage:(XMPPMessage *)message
NS_SWIFT_NAME(xmppOneToOneChat(_:didReceiveChatMessage:));

/// Notifies the delegate that a chat message has been sent in the stream.
- (void)xmppOneToOneChat:(XMPPOneToOneChat *)xmppOneToOneChat didSendChatMessage:(XMPPMessage *)message
NS_SWIFT_NAME(xmppOneToOneChat(_:didSendChatMessage:));

@end

NS_ASSUME_NONNULL_END
