#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE
  #import "DDXML.h"
#endif

@class XMPPJID;


@interface XMPPElement : NSXMLElement <NSCoding>

- (NSString *)elementID;

- (XMPPJID *)to;
- (XMPPJID *)from;

- (NSString *)toStr;
- (NSString *)fromStr;

- (BOOL)wasDelayed;
- (NSDate *)delayedDeliveryDate;

@end
