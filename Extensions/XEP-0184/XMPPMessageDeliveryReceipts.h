#import "XMPPModule.h"

#define _XMPP_MESSAGE_DELIVERY_RECEIPTS_H

@class XMPPMessage;

/**
 * XMPPMessageDeliveryReceipts can be configured to automatically send delivery receipts and requests in accordance to XEP-0184
**/

NS_ASSUME_NONNULL_BEGIN
@interface XMPPMessageDeliveryReceipts : XMPPModule

/**
 * Automatically add message delivery requests to outgoing messages, in all situations that are permitted in XEP-0184
 *
 * - Message MUST NOT be of type 'error' or 'groupchat'
 * - Message MUST have an id
 * - Message MUST NOT have a delivery receipt or request
 * - To must either be a bare JID or a full JID that advertises the urn:xmpp:receipts capability
 *
 * Default NO
**/

@property (assign) BOOL autoSendMessageDeliveryRequests;

/**
 * Automatically send message delivery receipts when a message with a delivery request is received 
 *
 * Default NO
**/

@property (assign) BOOL autoSendMessageDeliveryReceipts;

@end

/**
 * A protocol defining @c XMPPManagedMessaging module delegate API.
**/
@protocol XMPPMessageDeliveryReceiptsDelegate <NSObject>

@optional

/**
 * Notifies the delegate of a receipt response message received in the stream.
**/
- (void)xmppMessageDeliveryReceipts:(XMPPMessageDeliveryReceipts *)xmppMessageDeliveryReceipts didReceiveReceiptResponseMessage:(XMPPMessage *)message;

@end
NS_ASSUME_NONNULL_END
