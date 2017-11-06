#import "XMPPModule.h"

NS_ASSUME_NONNULL_BEGIN;

@class XMPPMessage;

/**
 A module that handles XEP-0308 message corrections.
 
 This module has the following interactions with other modules:
 - Reports XEP-0308 capability to @c XMPPCapabilities.
 - Observes MUC/MUC Light affiliation change callbacks to indicate that the last message can no longer be corrected after rejoining the room.
 */
@interface XMPPLastMessageCorrection : XMPPModule

/// Returns YES if a sent message with the given element ID can still be corrected, as per the respective XEP rules.
- (BOOL)canCorrectSentMessageWithID:(NSString *)messageID;

@end

/// A protocol defining @c XMPPLastMessageCorrection module delegate API.
@protocol XMPPLastMessageCorrectionDelegate <NSObject>

/// Notifies the delegate that a message correction has been received in the stream.
- (void)xmppLastMessageCorrection:(XMPPLastMessageCorrection *)xmppLastMessageCorrection didReceiveCorrectedMessage:(XMPPMessage *)correctedMessage;

@end

NS_ASSUME_NONNULL_END
