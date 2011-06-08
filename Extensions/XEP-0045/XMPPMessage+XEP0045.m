#import "XMPPMessage+XEP0045.h"
#import "NSXMLElement+XMPP.h"


@implementation XMPPMessage(XEP0045)

- (BOOL)isGroupChatMessage
{
	return [[[self attributeForName:@"type"] stringValue] isEqualToString:@"groupchat"];
}

- (BOOL)isGroupChatMessageWithBody
{
	if ([self isGroupChatMessage])
	{
		NSString *body = [[self elementForName:@"body"] stringValue];
		
		return ((body != nil) && ([body length] > 0));
	}
	
	return NO;
}

@end
