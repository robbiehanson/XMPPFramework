#import "XMPPUser.h"
#import "XMPPJID.h"
#import "XMPPIQ.h"
#import "XMPPPresence.h"
#import "XMPPResource.h"
#import "NSXMLElementAdditions.h"


@implementation XMPPUser

- (id)initWithItem:(NSXMLElement *)item
{
	if(self = [super init])
	{
		// Example item:
		// <item subscription='both' name='Johnathan' jid='robbiehanson15@deusty.com'/>
		
		NSString *jidStr = [[item attributeForName:@"jid"] stringValue];
		jid = [[XMPPJID jidWithString:jidStr] retain];
		
		itemAttributes = [[item attributesAsDictionary] mutableCopy];
		
		resources = [[NSMutableDictionary alloc] initWithCapacity:1];
	}
	return self;
}

- (void)dealloc
{
	[resources release];
	[jid release];
	[itemAttributes release];
	[primaryResource release];
	[super dealloc];
}

- (XMPPJID *)jid
{
	return jid;
}

- (NSString *)nickname
{
	return (NSString *)[itemAttributes objectForKey:@"name"];
}

- (NSString *)displayName
{
	NSString *nickname = [self nickname];
	if(nickname)
		return nickname;
	else
		return [jid bare];
}

- (BOOL)isOnline
{
	return (primaryResource != nil);
}

- (BOOL)isPendingApproval
{
	// Either of the following mean we're waiting to have our presence subscription approved:
	// <item ask='subscribe' subscription='none' jid='robbie@robbiehanson.com'/>
	// <item ask='subscribe' subscription='from' jid='robbie@robbiehanson.com'/>
	
	NSString *subscription = [itemAttributes objectForKey:@"subscription"];
	NSString *ask = [itemAttributes objectForKey:@"ask"];
	
	if([subscription isEqualToString:@"none"] || [subscription isEqualToString:@"from"])
	{
		if([ask isEqualToString:@"subscribe"])
		{
			return YES;
		}
	}
	
	return NO;
}

- (XMPPResource *)primaryResource
{
	return primaryResource;
}

- (NSArray *)sortedResources
{
	return [[resources allValues] sortedArrayUsingSelector:@selector(compare:)];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Helper Methods:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)recalculatePrimaryResource
{
	[primaryResource release];
	primaryResource = nil;
	
	NSArray *sortedResources = [self sortedResources];
	if([sortedResources count] > 0)
	{
		XMPPResource *possiblePrimary = [sortedResources objectAtIndex:0];
		
		// Primary resource must have a positive priority
		if([[possiblePrimary presence] priority] > 0)
		{
			primaryResource = [possiblePrimary retain];
		}
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Update Methods:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)updateWithItem:(NSXMLElement *)item
{
	NSArray *attributes = [item attributes];
	
	int i;
	for(i = 0; i < [attributes count]; i++)
	{
		NSXMLNode *node = [attributes objectAtIndex:i];
		NSString *key   = [node name];
		NSString *value = [node stringValue];
		
		if(![value isEqualToString:[itemAttributes objectForKey:key]])
		{
			[itemAttributes setObject:value forKey:key];
		}
	}
}

- (void)updateWithPresence:(XMPPPresence *)presence
{
	NSLog(@"---------- XMPPUser: updateWithPresence:");
	
	if([[presence type] isEqualToString:@"unavailable"])
	{
		[resources removeObjectForKey:[presence from]];
	}
	else
	{
		XMPPJID *key = [presence from];
		XMPPResource *resource = [resources objectForKey:key];
		
		if(resource)
		{
			[resource updateWithPresence:presence];
		}
		else
		{
			XMPPResource *newResource = [[XMPPResource alloc] initWithPresence:presence];
			[resources setObject:newResource forKey:key];
		}
	}
	
	[self recalculatePrimaryResource];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Comparison Methods:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Returns the result of invoking compareByName:options: with no options.
**/
- (NSComparisonResult)compareByName:(XMPPUser *)another
{
	return [self compareByName:another options:0];
}

/**
 * This method compares the two users according to their name.
 * If either of the users has no set name (or has an empty string name), the name is considered to be the JID.
 * 
 * Options for the search — you can combine any of the following using a C bitwise OR operator:
 * NSCaseInsensitiveSearch, NSLiteralSearch, NSNumericSearch.
 * See "String Programming Guide for Cocoa" for details on these options.
**/
- (NSComparisonResult)compareByName:(XMPPUser *)another options:(NSStringCompareOptions)mask
{
	NSString *myName = [self displayName];
	NSString *theirName = [another displayName];
	
	return [myName compare:theirName options:mask];
}

/**
 * Returns the result of invoking compareByAvailabilityName:options: with no options.
**/
- (NSComparisonResult)compareByAvailabilityName:(XMPPUser *)another
{
	return [self compareByAvailabilityName:another options:0];
}

/**
 * This method compares the two users according to availability first, and then name.
 * Thus available users come before unavailable users.
 * If both users are available, or both users are not available,
 * this method follows the same functionality as the compareByName:options: as documented above.
**/
- (NSComparisonResult)compareByAvailabilityName:(XMPPUser *)another options:(NSStringCompareOptions)mask
{
	if([self isOnline])
	{
		if([another isOnline])
			return [self compareByName:another options:mask];
		else
			return NSOrderedAscending;
	}
	else
	{
		if([another isOnline])
			return NSOrderedDescending;
		else
			return [self compareByName:another options:mask];
	}
}

@end
