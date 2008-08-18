#import <Foundation/Foundation.h>
#import "XMPPElement.h"


@interface XMPPMessage : XMPPElement

+ (XMPPMessage *)messageFromElement:(NSXMLElement *)element;

- (BOOL)isChatMessage;
- (BOOL)isChatMessageWithBody;

@end
