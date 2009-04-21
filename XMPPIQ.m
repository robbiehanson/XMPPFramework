#import "XMPPIQ.h"
#import "NSXMLElementAdditions.h"


@implementation XMPPIQ

+ (XMPPIQ *)iqFromElement:(NSXMLElement *)element
{
	XMPPIQ *result = (XMPPIQ *)element;
	result->isa = [XMPPIQ class];
	return result;
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
