#import "XMPPPresence.h"
#import "XMPPJID.h"
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
	if(self = [super initWithName:@"presence"])
	{
		[self addAttribute:[NSXMLNode attributeWithName:@"type" stringValue:type]];
		[self addAttribute:[NSXMLNode attributeWithName:@"to" stringValue:[to description]]];
	}
	return self;
}

- (NSString *)elementID
{
	return [[self attributeForName:@"id"] stringValue];
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
