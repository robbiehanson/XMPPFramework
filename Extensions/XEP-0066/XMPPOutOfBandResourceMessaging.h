#import "XMPPModule.h"

@class XMPPMessage;

NS_ASSUME_NONNULL_BEGIN

/// A module that handles incoming XEP-0066 Out of Band Data URI messages.
@interface XMPPOutOfBandResourceMessaging : XMPPModule

/// @brief The set of URL schemes handled by the module.
/// @discussion If set to @c nil (the default), URL filtering is disabled.
@property (copy, nullable) NSSet<NSString *> *relevantURLSchemes;

@end

/// A protocol defining @c XMPPOutOfBandResourceMessagingDelegate module delegate API.
@protocol XMPPOutOfBandResourceMessagingDelegate <NSObject>

@optional

/// Notifies the delegate that a message containing a relevant XEP-0066 Out of Band Data URI has been received in the stream.
- (void)xmppOutOfBandResourceMessaging:(XMPPOutOfBandResourceMessaging *)xmppOutOfBandResourceMessaging
    didReceiveOutOfBandResourceMessage:(XMPPMessage *)message
NS_SWIFT_NAME(xmppOutOfBandResourceMessaging(_:didReceiveOutOfBandResourceMessage:));

@end

NS_ASSUME_NONNULL_END
