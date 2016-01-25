#import <Foundation/Foundation.h>
@import KissXML;


@interface NSXMLElement (XEP_0203)

- (BOOL)wasDelayed;
- (NSDate *)delayedDeliveryDate;

@end
