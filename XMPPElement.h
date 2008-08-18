#import <Foundation/Foundation.h>
#import "XMPPJID.h"


@interface XMPPElement : NSXMLElement <NSCoding>

- (NSString *)elementID;

- (XMPPJID *)to;
- (XMPPJID *)from;

@end
