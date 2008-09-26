#import "XMPPUser.h"
#import "XMPPJID.h"
#import "XMPPIQ.h"
#import "XMPPPresence.h"
#import "XMPPResource.h"
#import "NSXMLElementAdditions.h"


@implementation XMPPUser

- (id)initWithJID:(XMPPJID *)aJid
{
	if(self = [super init])
	{
		jid = [[aJid bareJID] retain];
		itemAttributes = [[NSMutableDictionary alloc] initWithCapacity:0];
		resources = [[NSMutableDictionary alloc] initWithCapacity:1];
		
		tag = 0;
	}
	return self;
}

- (id)initWithItem:(NSXMLElement *)item
{
	if(self = [super init])
	{
		// Example item:
		// <item subscription='both' name='Robbie' jid='robbiehanson@deusty.com'/>
		
		NSString *jidStr = [[item attributeForName:@"jid"] stringValue];
		jid = [[[XMPPJID jidWithString:jidStr] bareJID] retain];
		
		itemAttributes = [[item attributesAsDictionary] mutableCopy];
		
		resources = [[NSMutableDictionary alloc] initWithCapacity:1];
		
		tag = 0;
	}
	return self;
}

- (void)dealloc
{
	[jid release];
	[itemAttributes release];
	[resources release];
	[primaryResource release];
	[super dealloc];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Encoding, Decoding
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#if ! TARGET_OS_IPHONE
- (id)replacementObjectForPortCoder:(NSPortCoder *)encoder
{
	if([encoder isBycopy])
		return self;
	else
		return [NSDistantObject proxyWithLocal:self connection:[encoder connection]];
}
#endif

- (id)initWithCoder:(NSCoder *)coder
{
	if(self = [super init])
	{
		if([coder allowsKeyedCoding])
		{
			jid             = [[coder decodeObjectForKey:@"jid"] retain];
			itemAttributes  = [[coder decodeObjectForKey:@"itemAttributes"] mutableCopy];
			resources       = [[coder decodeObjectForKey:@"resources"] mutableCopy];
			primaryResource = [[coder decodeObjectForKey:@"primaryResource"] retain];
			tag             = [coder decodeIntegerForKey:@"tag"];
		}
		else
		{
			jid             = [[coder decodeObject] retain];
			itemAttributes  = [[coder decodeObject] mutableCopy];
			resources       = [[coder decodeObject] mutableCopy];
			primaryResource = [[coder decodeObject] retain];
			tag             = [[coder decodeObject] integerValue];
		}
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	if([coder allowsKeyedCoding])
	{
		[coder encodeObject:jid             forKey:@"jid"];
		[coder encodeObject:itemAttributes  forKey:@"itemAttributes"];
		[coder encodeObject:resources       forKey:@"resources"];
		[coder encodeObject:primaryResource forKey:@"primaryResource"];
		[coder encodeInteger:tag            forKey:@"tag"];
	}
	else
	{
		[coder encodeObject:jid];
		[coder encodeObject:itemAttributes];
		[coder encodeObject:resources];
		[coder encodeObject:primaryResource];
		[coder encodeObject:[NSNumber numberWithInteger:tag]];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Standard Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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
	// <item ask='subscribe' subscription='none' jid='robbiehanson@deusty.com'/>
	// <item ask='subscribe' subscription='from' jid='robbiehanson@deusty.com'/>
	
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

- (NSArray *)unsortedResources
{
	return [resources allValues];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Helper Methods
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
#pragma mark Update Methods
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
			XMPPResource *newResource = [[[XMPPResource alloc] initWithPresence:presence] autorelease];
			[resources setObject:newResource forKey:key];
		}
	}
	
	[self recalculatePrimaryResource];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Comparison Methods
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
 * Options for the search Ñ you can combine any of the following using a C bitwise OR operator:
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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark NSObject Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSString *)description
{
	return [NSString stringWithFormat:@"XMPPUser: %@", [jid bare]];
}

- (BOOL)isEqual:(id)anObject
{
	if([anObject isMemberOfClass:[self class]])
	{
		XMPPUser *another = (XMPPUser *)anObject;
		
		return [jid isEqual:[another jid]];
	}
	
	return NO;
}

- (NSUInteger)hash
{
	return [jid hash];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark User Defined Content
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSInteger)tag
{
	return tag;
}

- (void)setTag:(NSInteger)anInt
{
	tag = anInt;
}

@end
