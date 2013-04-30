#import "XMPPMessage.h"

@interface XMPPMessage (XEP_0308)

- (BOOL)isCorrectionMessage;

- (NSString *)correctedMessageElementID;

@end
