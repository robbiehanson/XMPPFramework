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

- (XMPPJID *)to
{
	NSString *str = [[self attributeForName:@"to"] stringValue];
	return [XMPPJID jidWithString:str];
}

- (XMPPJID *)from
{
	NSString *str = [[self attributeForName:@"from"] stringValue];
	return [XMPPJID jidWithString:str];
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
