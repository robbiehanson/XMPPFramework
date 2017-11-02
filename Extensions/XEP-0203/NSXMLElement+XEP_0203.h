#import <Foundation/Foundation.h>
@import KissXML;

@class XMPPJID;

@interface NSXMLElement (XEP_0203)

@property (nonatomic, readonly) BOOL wasDelayed;
@property (nonatomic, readonly, nullable) NSDate *delayedDeliveryDate;
- (XMPPJID *)delayedDeliveryFrom;
- (NSString *)delayedDeliveryReasonDescription;

@end
