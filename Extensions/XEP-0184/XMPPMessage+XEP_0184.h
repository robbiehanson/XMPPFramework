#import <Foundation/Foundation.h>
#import "XMPPMessage.h"


@interface XMPPMessage (XEP_0184)

- (BOOL)hasReceiptRequest;
- (BOOL)hasReceiptResponse;
- (NSString *)extractReceiptResponseID;
- (XMPPMessage *)generateReceiptResponse;

@end
