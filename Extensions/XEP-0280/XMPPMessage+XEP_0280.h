#import "XMPPMessage.h"
@class XMPPJID;

NS_ASSUME_NONNULL_BEGIN
@interface XMPPMessage (XEP_0280)

@property (nonatomic, readonly, nullable) NSXMLElement *receivedMessageCarbon;
@property (nonatomic, readonly, nullable) NSXMLElement *sentMessageCarbon;

@property (nonatomic, readonly) BOOL isMessageCarbon;
@property (nonatomic, readonly) BOOL isReceivedMessageCarbon;
@property (nonatomic, readonly) BOOL isSentMessageCarbon;
@property (nonatomic, readonly) BOOL isTrustedMessageCarbon;
- (BOOL)isTrustedMessageCarbonForMyJID:(XMPPJID *)jid;

@property (nonatomic, readonly, nullable) XMPPMessage *messageCarbonForwardedMessage;

- (void)addPrivateMessageCarbons;

@end
NS_ASSUME_NONNULL_END
