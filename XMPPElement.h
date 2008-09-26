#import <Foundation/Foundation.h>
#import "DDXML.h"

@class XMPPJID;


@interface XMPPElement : NSXMLElement <NSCoding>

- (NSString *)elementID;

- (XMPPJID *)to;
- (XMPPJID *)from;

@end
