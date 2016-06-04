#import "XMPPMessage.h"
#import "XMPPFramework.h"

@interface XMPPMessage (XEP_0313)

- (BOOL) hasForwardedMessage;
- (NSString *)getResult;
- (XMPPMessage *) getforwardedMessage;


@end
