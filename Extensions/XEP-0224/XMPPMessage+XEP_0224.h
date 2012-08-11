#import "XMPPMessage.h"
#define XMLNS_ATTENTION  @"urn:xmpp:attention:0"

@interface XMPPMessage (XEP_0224) 
- (BOOL)isHeadLineMessage;
- (BOOL)isAttentionMessage;
- (BOOL)isAttentionMessageWithBody;
@end
