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

/**
 * Returns whether or not the IQ element is in the "jabber:iq:roster" namespace,
 * and thus represents a roster update.
**/
- (BOOL)isRosterQuery
{
	// Note: Some jabber servers send an iq element with a xmlns.
	// Because of the bug in Apple's NSXML (documented in our elementForName method),
	// it is important we specify the xmlns for the query.
	
	NSXMLElement *query = [self elementForName:@"query" xmlns:@"jabber:iq:roster"];
	
	return (query != nil);

}

@end
