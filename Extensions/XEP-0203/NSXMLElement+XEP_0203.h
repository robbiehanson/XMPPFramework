#import <Foundation/Foundation.h>
@import KissXML;

@class XMPPJID;

@interface NSXMLElement (XEP_0203)

@property (nonatomic, readonly) BOOL wasDelayed;
@property (nonatomic, readonly, nullable) NSDate *delayedDeliveryDate;
@property (nonatomic, readonly, nullable) XMPPJID *delayedDeliveryFrom;
@property (nonatomic, readonly, nullable) NSString *delayedDeliveryReasonDescription;

@end
