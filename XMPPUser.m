#import "XMPPUser.h"
#import "XMPPStream.h"

@implementation XMPPUser

- (id)initWithItem:(NSXMLElement *)item
{
	if(self = [super init])
	{
		NSArray *attributes = [item attributes];
		itemAttributes = [[NSMutableDictionary alloc] initWithCapacity:[attributes count]];
		
		int i;
		for(i = 0; i < [attributes count]; i++)
		{
			NSXMLNode *node = [attributes objectAtIndex:i];
			[itemAttributes setObject:[node stringValue] forKey:[node name]];
		}
		
		presence_type   = @"unavailable";
		presence_show   = @"normal";
		presence_status = @"";
	}
	return self;
}

- (void)dealloc
{
	[itemAttributes release];
	[presence_type release];
	[presence_show release];
	[presence_status release];
	[super dealloc];
}

- (BOOL)isOnline
{
	return [presence_type isEqualToString:@"available"];
}

- (BOOL)isPendingApproval
{
	NSString *subscription = (NSString *)[itemAttributes objectForKey:@"subscription"];
	if([subscription isEqualToString:@"none"])
		return YES;
	if([subscription isEqualToString:@"from"])
		return YES;
	
	return NO;
}

- (NSString *)jid {
	return (NSString *)[itemAttributes objectForKey:@"jid"];
}
- (NSString *)name {
	return (NSString *)[itemAttributes objectForKey:@"name"];
}

- (NSString *)show {
	return presence_show;
}
- (NSString *)status {
	return presence_status;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Update Methods:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method updates the user information with the info from the given iq element.
 * It is assumed the given item element has the same JID as this user.
 * 
 * Item elements come from query elements inside IQ elements.
**/
- (void)updateWithItem:(NSXMLElement *)item
{
	NSArray *attributes = [item attributes];
	
	int i;
	for(i = 0; i < [attributes count]; i++)
	{
		NSXMLNode *node = [attributes objectAtIndex:i];
		[itemAttributes setObject:[node stringValue] forKey:[node name]];
	}
}

/**
 * This method updates the user information with the info from the given presence element.
 * It is assumed the given presence element has the same JID as this user.
**/
- (void)updateWithPresence:(NSXMLElement *)presence
{
	// Extract the value of the type attribute, if available
	NSXMLNode *typeAttribute = [presence attributeForName:@"type"];
	if(typeAttribute)
	{
		[presence_type release];
		presence_type = [[typeAttribute stringValue] retain];
	}
	else
	{
		// If no type attribute is specified, then the value of available is assumed
		[presence_type release];
		presence_type = @"available";
	}
	
	// Extract the value of the show element, if available
	// By convention will be one of the following: away, chat, dnd, normal, or xa.
	NSXMLElement *showElement = [presence elementForName:@"show"];
	if(showElement)
	{
		[presence_show release];
		presence_show = [[showElement stringValue] retain];
	}
	else
	{
		// If no <show/> tag is specified in an available <presence/> element, a value of normal is assumed
		[presence_show release];
		presence_show = @"normal";
	}
	
	// Extract the value of the status element, if available
	// These are custom messages, such as an away message
	NSXMLElement *status = [presence elementForName:@"status"];
	if(status)
	{
		[presence_status release];
		presence_status = [[status stringValue] retain];
	}
	else
	{
		// Custom status messages do not have a default value (obviously)
		[presence_status release];
		presence_status = @"";
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Low-Level Access:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method allows for quickly marking the user as offline.
 * Calling this method will not result in any notifications being posted by the XMPPUser object.
**/
- (void)setAsOffline
{
	[presence_type autorelease];
	[presence_show autorelease];
	[presence_status autorelease];
	
	presence_type   = @"unavailable";
	presence_show   = @"";
	presence_status = @"";
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Comparison Methods:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Returns the result of invoking compareByName:options: with no options.
**/
- (NSComparisonResult)compareByName:(XMPPUser *)user
{
	return [self compareByName:user options:0];
}

/**
 * This method compares the two users according to their name.
 * If either of the users has no set name (or has an empty string name), the name is considered to be the JID.
 * 
 * Options for the search — you can combine any of the following using a C bitwise OR operator:
 * NSCaseInsensitiveSearch, NSLiteralSearch, NSNumericSearch.
 * See "String Programming Guide for Cocoa" for details on these options.
**/
- (NSComparisonResult)compareByName:(XMPPUser *)user options:(unsigned)mask
{
	NSString *selfName = [self name];
	if([selfName length] == 0)
		selfName = [self jid];
	
	NSString *userName = [user name];
	if([userName length] == 0)
		userName = [user jid];
	
	return [selfName compare:userName options:mask];
}

/**
 * Returns the result of invoking compareByAvailabilityName:options: with no options.
**/
- (NSComparisonResult)compareByAvailabilityName:(XMPPUser *)user
{
	return [self compareByAvailabilityName:user options:0];
}

/**
 * This method compares the two users according to availability first, and then name.
 * Thus available users come before unavailable users.
 * If both users are available, or both users are not available,
 * this method follows the same functionality as the compareByName:options: as documented above.
**/
- (NSComparisonResult)compareByAvailabilityName:(XMPPUser *)user options:(unsigned)mask
{
	if([self isOnline])
	{
		if(![user isOnline])
			return NSOrderedAscending;
	}
	else
	{
		if([user isOnline])
			return NSOrderedDescending;
	}
	
	NSString *selfName = [self name];
	if([selfName length] == 0)
		selfName = [self jid];
	
	NSString *userName = [user name];
	if([userName length] == 0)
		userName = [user jid];
	
	return [selfName compare:userName options:mask];
}

@end
