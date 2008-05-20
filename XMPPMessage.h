#import <Cocoa/Cocoa.h>
@class  XMPPJID;


@interface XMPPMessage : NSXMLElement

+ (XMPPMessage *)messageFromElement:(NSXMLElement *)element;

- (XMPPJID *)to;
- (XMPPJID *)from;

- (BOOL)isChatMessage;
- (BOOL)isChatMessageWithBody;

@end
