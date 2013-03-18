#import "XMPPIQ.h"
#import "XMPPJID.h"
#import "NSXMLElement+XMPP.h"

#import <objc/runtime.h>

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif


@implementation XMPPIQ

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
	size_t ourSize   = class_getInstanceSize([XMPPIQ class]);
	
	if (superSize != ourSize)
	{
		NSLog(@"Adding instance variables to XMPPIQ is not currently supported!");
		exit(15);
	}
}

+ (XMPPIQ *)iqFromElement:(NSXMLElement *)element
{
	object_setClass(element, [XMPPIQ class]);
	
	return (XMPPIQ *)element;
}

+ (XMPPIQ *)iq
{
	return [[XMPPIQ alloc] initWithType:nil to:nil elementID:nil child:nil];
}

+ (XMPPIQ *)iqWithType:(NSString *)type
{
	return [[XMPPIQ alloc] initWithType:type to:nil elementID:nil child:nil];
}

+ (XMPPIQ *)iqWithType:(NSString *)type to:(XMPPJID *)jid
{
	return [[XMPPIQ alloc] initWithType:type to:jid elementID:nil child:nil];
}

+ (XMPPIQ *)iqWithType:(NSString *)type to:(XMPPJID *)jid elementID:(NSString *)eid
{
	return [[XMPPIQ alloc] initWithType:type to:jid elementID:eid child:nil];
}

+ (XMPPIQ *)iqWithType:(NSString *)type to:(XMPPJID *)jid elementID:(NSString *)eid child:(NSXMLElement *)childElement
{
	return [[XMPPIQ alloc] initWithType:type to:jid elementID:eid child:childElement];
}

+ (XMPPIQ *)iqWithType:(NSString *)type elementID:(NSString *)eid
{
	return [[XMPPIQ alloc] initWithType:type to:nil elementID:eid child:nil];
}

+ (XMPPIQ *)iqWithType:(NSString *)type elementID:(NSString *)eid child:(NSXMLElement *)childElement
{
	return [[XMPPIQ alloc] initWithType:type to:nil elementID:eid child:childElement];
}

+ (XMPPIQ *)iqWithType:(NSString *)type child:(NSXMLElement *)childElement
{
	return [[XMPPIQ alloc] initWithType:type to:nil elementID:nil child:childElement];
}

- (id)init
{
	return [self initWithType:nil to:nil elementID:nil child:nil];
}

- (id)initWithType:(NSString *)type
{
	return [self initWithType:type to:nil elementID:nil child:nil];
}

- (id)initWithType:(NSString *)type to:(XMPPJID *)jid
{
	return [self initWithType:type to:jid elementID:nil child:nil];
}

- (id)initWithType:(NSString *)type to:(XMPPJID *)jid elementID:(NSString *)eid
{
	return [self initWithType:type to:jid elementID:eid child:nil];
}

- (id)initWithType:(NSString *)type to:(XMPPJID *)jid elementID:(NSString *)eid child:(NSXMLElement *)childElement
{
	if ((self = [super initWithName:@"iq"]))
	{
		if (type)
			[self addAttributeWithName:@"type" stringValue:type];
		
		if (jid)
			[self addAttributeWithName:@"to" stringValue:[jid full]];
		
		if (eid)
			[self addAttributeWithName:@"id" stringValue:eid];
		
		if (childElement)
			[self addChild:childElement];
	}
	return self;
}

- (id)initWithType:(NSString *)type elementID:(NSString *)eid
{
	return [self initWithType:type to:nil elementID:eid child:nil];
}

- (id)initWithType:(NSString *)type elementID:(NSString *)eid child:(NSXMLElement *)childElement
{
	return [self initWithType:type to:nil elementID:eid child:childElement];
}

- (id)initWithType:(NSString *)type child:(NSXMLElement *)childElement
{
	return [self initWithType:type to:nil elementID:nil child:childElement];
}

- (NSString *)type
{
	return [[self attributeStringValueForName:@"type"] lowercaseString];
}

- (BOOL)isGetIQ
{
	return [[self type] isEqualToString:@"get"];
}

- (BOOL)isSetIQ
{
	return [[self type] isEqualToString:@"set"];
}

- (BOOL)isResultIQ
{
	return [[self type] isEqualToString:@"result"];
}

- (BOOL)isErrorIQ
{
	return [[self type] isEqualToString:@"error"];
}

- (BOOL)requiresResponse
{
	// An entity that receives an IQ request of type "get" or "set" MUST reply with an IQ response
	// of type "result" or "error" (the response MUST preserve the 'id' attribute of the request).
	
	return [self isGetIQ] || [self isSetIQ];
}

- (NSXMLElement *)childElement
{
	NSArray *children = [self children];
	for (NSXMLElement *child in children)
	{
		// Careful: NSOrderedSame == 0
		
		NSString *childName = [child name];
		if (childName && ([childName caseInsensitiveCompare:@"error"] != NSOrderedSame))
		{
			return child;
		}
	}
	
	return nil;
}

- (NSXMLElement *)childErrorElement
{
	NSArray *children = [self children];
	for (NSXMLElement *child in children)
	{
		// Careful: NSOrderedSame == 0
		
		NSString *childName = [child name];
		if (childName && ([childName caseInsensitiveCompare:@"error"] == NSOrderedSame))
		{
			return child;
		}
	}
	
	return nil;
}

@end
