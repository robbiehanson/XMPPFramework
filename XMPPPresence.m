#import "XMPPPresence.h"
#import "NSXMLElementAdditions.h"


@implementation XMPPPresence

+ (XMPPPresence *)presenceFromElement:(NSXMLElement *)element
{
	XMPPPresence *result = (XMPPPresence *)element;
	result->isa = [XMPPPresence class];
	return result;
}

- (id)initWithType:(NSString *)type to:(XMPPJID *)to
{
	if((self = [super initWithName:@"presence"]))
	{
		[self addAttributeWithName:@"type" stringValue:type];
		[self addAttributeWithName:@"to" stringValue:[to description]];
	}
	return self;
}

- (NSString *)type
{
	NSString *type = [[self attributeForName:@"type"] stringValue];
	if(type)
		return type;
	else
		return @"available";
}

- (NSString *)show
{
	return [[self elementForName:@"show"] stringValue];
}

- (NSString *)status
{
	return [[self elementForName:@"status"] stringValue];
}

- (int)priority
{
	return [[[self elementForName:@"priority"] stringValue] intValue];
}

- (int)intShow
{
	NSString *show = [self show];
	
	if([show isEqualToString:@"dnd"])
		return 0;
	if([show isEqualToString:@"xa"])
		return 1;
	if([show isEqualToString:@"away"])
		return 2;
	if([show isEqualToString:@"chat"])
		return 4;
	
	return 3;
}

@end
