#import "XMPPMessage.h"

NS_ASSUME_NONNULL_BEGIN
@interface XMPPMessage (XEP_0308)

@property (nonatomic, readonly) BOOL isMessageCorrection;

@property (nonatomic, readonly, nullable) NSString *correctedMessageID;

- (void)addMessageCorrectionWithID:(NSString *)messageCorrectionID;

- (nullable XMPPMessage *)generateCorrectionMessageWithID:(nullable NSString *)elementID;
- (nullable XMPPMessage *)generateCorrectionMessageWithID:(nullable NSString *)elementID body:(NSString *)body;

@end
NS_ASSUME_NONNULL_END
