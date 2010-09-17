#import "XMPPPresence.h"
#import "NSXMLElementAdditions.h"

#import <objc/runtime.h>


@implementation XMPPPresence

+ (void)initialize
{
	// We use the object_setClass method below to dynamically change the class from a standard NSXMLElement.
	// The size of the two classes is expected to be the same.
	// 
	// If a developer adds instance methods to this class, bad things happen at runtime that are very hard to debug.
	// This check is here to aid future developers who may make this mistake.
	// 
	// For Fearless And Experienced Objective-C Developers:
	// It may be possible to support adding instance variables to this class if you seriously need it.
	// To do so, try realloc'ing self after altering the class, and then initialize your variables.
	
	size_t superSize = class_getInstanceSize([NSXMLElement class]);
	size_t ourSize   = class_getInstanceSize([XMPPPresence class]);
	
	if (superSize != ourSize)
	{
		NSLog(@"Adding instance variables to XMPPPresence is not currently supported!");
		exit(15);
	}
}

+ (XMPPPresence *)presenceFromElement:(NSXMLElement *)element
{
	object_setClass(element, [XMPPPresence class]);
	
	return (XMPPPresence *)element;
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
	NSString *type = [self attributeStringValueForName:@"type"];
	if(type)
		return [type lowercaseString];
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
