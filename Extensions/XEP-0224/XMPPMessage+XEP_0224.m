#import "XMPPMessage+XEP_0224.h"
#import "NSXMLElement+XMPP.h"

@implementation XMPPMessage (XEP_0224)

- (BOOL)isHeadLineMessage {
    return [[[self attributeForName:@"type"] stringValue] isEqualToString:@"headline"];
}

- (BOOL)isAttentionMessage
{
	return  [self isHeadLineMessage] && [self elementForName:@"attention" xmlns:XMLNS_ATTENTION];
}

- (BOOL)isAttentionMessageWithBody
{
	if([self isAttentionMessage])
	{
		return [self isMessageWithBody];
	}
	return NO;
}

@end
