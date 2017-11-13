#import "XMPP.h"

NS_ASSUME_NONNULL_BEGIN

/// A module for processing XEP-0203 Delayed Delivery information in incoming XMPP stanzas.
@interface XMPPDelayedDelivery : XMPPModule

@end

/// A protocol defining @c XMPPDelayedDelivery module delegate API.
@protocol XMPPDelayedDeliveryDelegate <NSObject>

@optional

/// Notifies the delegate that a delayed delivery message has been received in the stream.
- (void)xmppDelayedDelivery:(XMPPDelayedDelivery *)xmppDelayedDelivery
   didReceiveDelayedMessage:(XMPPMessage *)delayedMessage;

/// Notifies the delegate that a delayed delivery presence has been received in the stream.
- (void)xmppDelayedDelivery:(XMPPDelayedDelivery *)xmppDelayedDelivery
  didReceiveDelayedPresence:(XMPPPresence *)delayedPresence;

@end

NS_ASSUME_NONNULL_END
