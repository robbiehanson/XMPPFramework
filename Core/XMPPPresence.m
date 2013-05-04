#import "XMPPPresence.h"
#import "XMPPJID.h"
#import "NSXMLElement+XMPP.h"

#import <objc/runtime.h>

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif


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

+ (XMPPPresence *)presence
{
	return [[XMPPPresence alloc] init];
}

+ (XMPPPresence *)presenceWithType:(NSString *)type
{
	return [[XMPPPresence alloc] initWithType:type to:nil];
}

+ (XMPPPresence *)presenceWithType:(NSString *)type to:(XMPPJID *)to
{
	return [[XMPPPresence alloc] initWithType:type to:to];
}

- (id)init
{
	self = [super initWithName:@"presence"];
	return self;
}

- (id)initWithType:(NSString *)type
{
	return [self initWithType:type to:nil];
}

- (id)initWithType:(NSString *)type to:(XMPPJID *)to
{
	if ((self = [super initWithName:@"presence"]))
	{
		if (type)
			[self addAttributeWithName:@"type" stringValue:type];
		
		if (to)
			[self addAttributeWithName:@"to" stringValue:[to description]];
	}
	return self;
}

- (id)initWithXMLString:(NSString *)string error:(NSError *__autoreleasing *)error
{
	if((self = [super initWithXMLString:string error:error])){
		self = [XMPPPresence presenceFromElement:self];
	}	
	return self;
}

- (NSString *)type
{
	NSString *type = [self attributeStringValueForName:@"type"];
	return [type lowercaseString];
}

- (void)setType:(NSString *)type
{
	[self removeAttributeForName:@"type"];
	if ([type length])
		[self addAttributeWithName:@"type" stringValue:type];
}

- (NSString *)show
{
	return [[self elementForName:@"show"] stringValue];
}

- (void)setShow:(NSString *)show
{
	NSXMLElement *showElement = [self elementForName:@"show"];
	if (!showElement) {
		showElement = [NSXMLElement elementWithName:@"show"];
		[self addChild:showElement];
	}
	[showElement setStringValue:show];
}

- (NSString *)status
{
	return [[self elementForName:@"status"] stringValue];
}

- (void)setStatus:(NSString *)status
{
	NSXMLElement *statusElement = [self elementForName:@"status"];
	if (!statusElement) {
		statusElement = [NSXMLElement elementWithName:@"status"];
		[self addChild:statusElement];
	}
	[statusElement setStringValue:status];
}

- (NSInteger)priority
{
	return [[[self elementForName:@"priority"] stringValue] integerValue];
}

- (void)setPriority:(NSInteger)priority
{
	NSXMLElement *priorityElement = [self elementForName:@"priority"];
	if (!priorityElement) {
		priorityElement = [NSXMLElement elementWithName:@"priority"];
		[self addChild:priorityElement];
	}
	[priorityElement setStringValue:[[NSNumber numberWithInteger:priority] stringValue]];
}

- (XMPPPresenceShowType)showType
{
	NSString *show = [self show];
	if ([show isEqualToString:@"dnd"])
		return XMPPPresenceShowBusy;
	if ([show isEqualToString:@"xa"])
		return XMPPPresenceShowExtendedAway;
	if ([show isEqualToString:@"away"])
		return XMPPPresenceShowAway;
	if ([show isEqualToString:@"chat"])
		return XMPPPresenceShowChat;
	return XMPPPresenceShowNone;
}

- (void)setShowType:(XMPPPresenceShowType)showType
{
	NSString *show = nil;
	switch (showType) {
		case XMPPPresenceShowBusy:
			show = @"dnd";
			break;
		case XMPPPresenceShowExtendedAway:
			show = @"xa";
			break;
		case XMPPPresenceShowAway:
			show = @"away";
			break;
		case XMPPPresenceShowChat:
			show = @"chat";
			break;
		default:
			break;
	}
	self.show = show;
}

- (BOOL)available
{
	if (self.type)
		return ![self.type isEqualToString:@"unavailable"];
	return YES;
}

- (void)setAvailable:(BOOL)available
{
	self.type = available ? nil : @"unavailable";
}

- (XMPPJID *)from
{
	NSString *from = [self attributeStringValueForName:@"from"];
	if ([from length])
		return [XMPPJID jidWithString:from];
	return nil;
}

- (void)setFrom:(XMPPJID *)from
{
	[self removeAttributeForName:@"from"];
	[self addAttributeWithName:@"from" stringValue:[from description]];
}

- (XMPPJID *)to
{
	NSString *to = [self attributeStringValueForName:@"to"];
	if ([to length])
		return [XMPPJID jidWithString:to];
	return nil;
}

- (void)setTo:(XMPPJID *)to
{
	[self removeAttributeForName:@"to"];
	[self addAttributeWithName:@"to" stringValue:[to description]];
}

- (int)intShow
{
	NSString *show = [self show];
	
	if ([show isEqualToString:@"dnd"])
		return 0;
	if ([show isEqualToString:@"xa"])
		return 1;
	if ([show isEqualToString:@"away"])
		return 2;
	if ([show isEqualToString:@"chat"])
		return 4;
	
	return 3;
}

- (BOOL)isErrorPresence
{
	return [[self type] isEqualToString:@"error"];
}
@end
