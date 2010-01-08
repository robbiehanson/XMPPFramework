#import "XMPPIQ.h"
#import "NSXMLElementAdditions.h"

#import <objc/objc-runtime.h>


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
 * For some bizarre reason (in my opinion), when you request your roster,
 * the server will return JID's NOT in your roster. These are the JID's of users who have requested
 * to be alerted to our presence.  After we sign in, we'll again be notified, via the normal presence request objects.
 * It's redundant, and annoying, and just plain incorrect to include these JID's when we request our personal roster.
 * So now, we have to go to the extra effort to filter out these JID's, which is exactly what this method does.
**/
+ (BOOL)isRosterItem:(NSXMLElement *)item
{
	NSXMLNode *subscription = [item attributeForName:@"subscription"];
	if([[subscription stringValue] isEqualToString:@"none"])
	{
		NSXMLNode *ask = [item attributeForName:@"ask"];
		if([[ask stringValue] isEqualToString:@"subscribe"])
		{
			return YES;
		}
		else
		{
			return NO;
		}
	}
	
	return YES;
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
