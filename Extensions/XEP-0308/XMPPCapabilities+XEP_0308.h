#import "XMPPCapabilities.h"

NS_ASSUME_NONNULL_BEGIN

@class XMPPJID;

@interface XMPPCapabilities (XEP_0308)

/// Returns YES if it has been determined that the entity with the given JID is capable of receiving XEP-0308 correction messages.
- (BOOL)isLastMessageCorrectionCapabilityConfirmedForJID:(XMPPJID *)jid;

@end

NS_ASSUME_NONNULL_END
