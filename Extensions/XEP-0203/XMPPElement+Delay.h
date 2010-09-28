#import <Foundation/Foundation.h>
#import "XMPPElement.h"


@interface XMPPElement (XEP0203)

- (BOOL)wasDelayed;
- (NSDate *)delayedDeliveryDate;

@end
