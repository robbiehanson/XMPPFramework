#import <Foundation/Foundation.h>
@import KissXML;


@interface NSXMLElement (XEP_0203)

@property (nonatomic, readonly) BOOL wasDelayed;
@property (nonatomic, readonly, nullable) NSDate *delayedDeliveryDate;

@end
