#import "XMPPMessage.h"

/** "urn:xmpp:attention:0" */
FOUNDATION_EXPORT NSString *const XMLNS_ATTENTION;

@interface XMPPMessage (XEP_0224) 
@property (nonatomic, readonly) BOOL isHeadLineMessage;
@property (nonatomic, readonly) BOOL isAttentionMessage;
@property (nonatomic, readonly) BOOL isAttentionMessageWithBody;
@end
