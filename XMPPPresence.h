#import <Cocoa/Cocoa.h>
@class  XMPPJID;


@interface XMPPPresence : NSXMLElement

+ (XMPPPresence *)presenceFromElement:(NSXMLElement *)element;

- (id)initWithType:(NSString *)type to:(XMPPJID *)to;

- (NSString *)elementID;

- (XMPPJID *)to;
- (XMPPJID *)from;
- (NSString *)type;

- (NSString *)show;
- (NSString *)status;

- (int)priority;

- (int)intShow;

@end
