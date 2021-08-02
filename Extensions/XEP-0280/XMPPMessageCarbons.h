#import "XMPPModule.h"
@class XMPPMessage;
@class XMPPIDTracker;

#define _XMPP_MESSAGE_CARBONS_H

NS_ASSUME_NONNULL_BEGIN
@interface XMPPMessageCarbons : XMPPModule

/**
 * Wether or not to automatically enable Message Carbons.
 *
 * Default YES
**/
@property (assign) BOOL autoEnableMessageCarbons;

/**
 * Wether Message Carbons is currently enabled or not.
 *
 * @see enableMessageCarbons
 * @see disableMessageCarbons
**/
@property (atomic, readonly) BOOL isMessageCarbonsEnabled;

/**
 * Whether Message Carbons are validated before calling the delegate methods.
 *
 * @see xmppMessageCarbons:willReceiveMessage:outgoing:
 * @see xmppMessageCarbons:didReceiveMessage:outgoing:
 *
 * A Message Carbon is Trusted if:
 *
 * - It is from the Stream's Bare JID
 * - Sent Forward Messages are from the Stream's JID
 * - Received Forward Messages are to the Stream's JID
 *
 * Default is NO
**/
@property (assign) BOOL allowsUntrustedMessageCarbons;

/**
 * Enable Message Carbons
**/
- (void)enableMessageCarbons;

/**
 * Disable Message Carbons
**/
- (void)disableMessageCarbons;

@end

@protocol XMPPMessageCarbonsDelegate <NSObject>
@optional

- (void)xmppMessageCarbons:(XMPPMessageCarbons *)xmppMessageCarbons willReceiveMessage:(XMPPMessage *)message outgoing:(BOOL)isOutgoing;

- (void)xmppMessageCarbons:(XMPPMessageCarbons *)xmppMessageCarbons didReceiveMessage:(XMPPMessage *)message outgoing:(BOOL)isOutgoing;

@end
NS_ASSUME_NONNULL_END
