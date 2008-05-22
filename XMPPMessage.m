#import "XMPPMessage.h"
#import "XMPPJID.h"
#import "NSXMLElementAdditions.h"


@implementation XMPPMessage

+ (XMPPMessage *)messageFromElement:(NSXMLElement *)element
{
	XMPPMessage *result = (XMPPMessage *)element;
	result->isa = [XMPPMessage class];
	return result;
}

- (BOOL)isChatMessage
{
	return [[[self attributeForName:@"type"] stringValue] isEqualToString:@"chat"];
}

- (BOOL)isChatMessageWithBody
{
	if([self isChatMessage])
	{
		NSString *body = [[self elementForName:@"body"] stringValue];
		
		return ((body != nil) && ([body length] > 0));
	}
	
	return NO;
}

@end
