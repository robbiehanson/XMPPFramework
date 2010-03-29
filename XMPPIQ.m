#import "XMPPIQ.h"
#import "NSXMLElementAdditions.h"

#import <objc/runtime.h>


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

- (NSString *)type
{
	return [[self attributeStringValueForName:@"type"] lowercaseString];
}

- (NSXMLElement *)queryElement
{
#if TARGET_OS_IPHONE
	return [self elementForName:@"query"];
#else
	NSArray *children = [self children];
	for (NSXMLElement *child in children)
	{
		if ([[child name] isEqualToString:@"query"])
		{
			return child;
		}
	}
	return nil;
#endif
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

@end
