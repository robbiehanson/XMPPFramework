#import <Foundation/Foundation.h>
#import "XMPPMessage.h"

NS_ASSUME_NONNULL_BEGIN
@interface XMPPMessage (XEP_0184)

@property (nonatomic, readonly) BOOL hasReceiptRequest;
@property (nonatomic, readonly) BOOL hasReceiptResponse;
@property (nonatomic, readonly, nullable) NSString *receiptResponseID;
@property (nonatomic, readonly, nullable) XMPPMessage *generateReceiptResponse;

- (void)addReceiptRequest;

@end
NS_ASSUME_NONNULL_END
