#import "XMPP.h"
#import "XMPPRosterMemoryStoragePrivate.h"


@interface XMPPUserMemoryStorage (PrivateAPI)
- (void)recalculatePrimaryResource;
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPUserMemoryStorage

- (id)initWithJID:(XMPPJID *)aJid
{
	if ((self = [super init]))
	{
		jid = [[aJid bareJID] retain];
		
		itemAttributes = [[NSMutableDictionary alloc] initWithCapacity:0];
		
		resources = [[NSMutableDictionary alloc] initWithCapacity:1];
	}
	return self;
}

- (id)initWithItem:(NSXMLElement *)item
{
	if ((self = [super init]))
	{
		NSString *jidStr = [item attributeStringValueForName:@"jid"];
		jid = [[[XMPPJID jidWithString:jidStr] bareJID] retain];
		
		itemAttributes = [[item attributesAsDictionary] retain];
		
		resources = [[NSMutableDictionary alloc] initWithCapacity:1];
	}
	return self;
}

- (void)dealloc
{
	[jid release];
	[itemAttributes release];
	[resources release];
	[primaryResource release];
	[photo release];
	[super dealloc];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Copying
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (id)copyWithZone:(NSZone *)zone
{
	// We use [self class] to support subclassing
	
	XMPPUserMemoryStorage *deepCopy = (XMPPUserMemoryStorage *)[[[self class] alloc] init];
	
	deepCopy->jid = [jid copy];
	deepCopy->itemAttributes = [itemAttributes mutableCopy];
	
	deepCopy->resources = [[NSMutableDictionary alloc] initWithCapacity:[resources count]];
	
	for (XMPPJID *key in resources)
	{
		XMPPResourceMemoryStorage *resourceCopy = [[resources objectForKey:key] copy];
		
		[deepCopy->resources setObject:resourceCopy forKey:key];
		[resourceCopy release];
	}
	
	[deepCopy recalculatePrimaryResource];
	
	return deepCopy;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Encoding, Decoding
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#if ! TARGET_OS_IPHONE
- (id)replacementObjectForPortCoder:(NSPortCoder *)encoder
{
	if ([encoder isBycopy])
		return self;
	else
		return [super replacementObjectForPortCoder:encoder];
	//	return [NSDistantObject proxyWithLocal:self connection:[encoder connection]];
}
#endif

- (id)initWithCoder:(NSCoder *)coder
{
	if ((self = [super init]))
	{
		if ([coder allowsKeyedCoding])
		{
			jid             = [[coder decodeObjectForKey:@"jid"] retain];
			itemAttributes  = [[coder decodeObjectForKey:@"itemAttributes"] mutableCopy];
		#if TARGET_OS_IPHONE
			photo           = [[UIImage alloc] initWithData:[coder decodeObjectForKey:@"photo"]];
		#else
			photo           = [[NSImage alloc] initWithData:[coder decodeObjectForKey:@"photo"]];
		#endif
			resources       = [[coder decodeObjectForKey:@"resources"] mutableCopy];
			primaryResource = [[coder decodeObjectForKey:@"primaryResource"] retain];
		}
		else
		{
			jid             = [[coder decodeObject] retain];
			itemAttributes  = [[coder decodeObject] mutableCopy];
		#if TARGET_OS_IPHONE
			photo           = [[UIImage alloc] initWithData:[coder decodeObject]];
		#else
			photo           = [[NSImage alloc] initWithData:[coder decodeObject]];
		#endif	
			resources       = [[coder decodeObject] mutableCopy];
			primaryResource = [[coder decodeObject] retain];
		}
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	if ([coder allowsKeyedCoding])
	{
		[coder encodeObject:jid forKey:@"jid"];
		[coder encodeObject:itemAttributes forKey:@"itemAttributes"];
	#if TARGET_OS_IPHONE
		[coder encodeObject:UIImagePNGRepresentation(photo) forKey:@"photo"];
	#else
		[coder encodeObject:[photo TIFFRepresentation] forKey:@"photo"];
	#endif
		[coder encodeObject:resources forKey:@"resources"];
		[coder encodeObject:primaryResource forKey:@"primaryResource"];
	}
	else
	{
		[coder encodeObject:jid];
		[coder encodeObject:itemAttributes];
	#if TARGET_OS_IPHONE
		[coder encodeObject:UIImagePNGRepresentation(photo)];
	#else
		[coder encodeObject:[photo TIFFRepresentation]];
	#endif
		[coder encodeObject:resources];
		[coder encodeObject:primaryResource];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Standard Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@synthesize photo;

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
	if (nickname)
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
	
	if ([subscription isEqualToString:@"none"] || [subscription isEqualToString:@"from"])
	{
		if([ask isEqualToString:@"subscribe"])
		{
			return YES;
		}
	}
	
	return NO;
}

- (id <XMPPResource>)primaryResource
{
	return primaryResource;
}

- (id <XMPPResource>)resourceForJID:(XMPPJID *)aJid
{
	return [resources objectForKey:aJid];
}

- (NSArray *)allResources
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
	
	NSArray *sortedResources = [[self allResources] sortedArrayUsingSelector:@selector(compare:)];
	if ([sortedResources count] > 0)
	{
		XMPPResourceMemoryStorage *possiblePrimary = [sortedResources objectAtIndex:0];
		
		// Primary resource must have a non-negative priority
		if ([[possiblePrimary presence] priority] >= 0)
		{
			primaryResource = [possiblePrimary retain];
		}
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Update Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)clearAllResources
{
	[resources removeAllObjects];
	
	[primaryResource release];
	primaryResource = nil;
}

- (void)updateWithItem:(NSXMLElement *)item
{
	for (NSXMLNode *node in [item attributes])
	{
		NSString *key   = [node name];
		NSString *value = [node stringValue];
		
		[itemAttributes setObject:value forKey:key];
	}
}

- (int)updateWithPresence:(XMPPPresence *)presence
            resourceClass:(Class)resourceClass
           andGetResource:(XMPPResourceMemoryStorage **)resourcePtr
{
	int result = XMPP_USER_NO_CHANGE;
	XMPPResourceMemoryStorage *resource;
	
	XMPPJID *key = [presence from];
	NSString *presenceType = [presence type];
	
	if ([presenceType isEqualToString:@"unavailable"] || [presenceType isEqualToString:@"error"])
	{
		resource = [[[resources objectForKey:key] retain] autorelease];
		if (resource)
		{
			[resources removeObjectForKey:key];
			result = XMPP_USER_REMOVED_RESOURCE;
		}
	}
	else
	{
		resource = [resources objectForKey:key];
		if (resource)
		{
			[resource updateWithPresence:presence];
			result = XMPP_USER_UPDATED_RESOURCE;
		}
		else
		{
			resource = (XMPPResourceMemoryStorage *)[[[resourceClass alloc] initWithPresence:presence] autorelease];
			
			[resources setObject:resource forKey:key];
			result = XMPP_USER_ADDED_RESOURCE;
		}
	}
	
	[self recalculatePrimaryResource];
	
	if (resourcePtr)
		*resourcePtr = resource;
	return result;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Comparisons
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Returns the result of invoking compareByName:options: with no options.
**/
- (NSComparisonResult)compareByName:(XMPPUserMemoryStorage *)another
{
	return [self compareByName:another options:0];
}

/**
 * This method compares the two users according to their display name.
 * 
 * Options for the search — you can combine any of the following using a C bitwise OR operator:
 * NSCaseInsensitiveSearch, NSLiteralSearch, NSNumericSearch.
 * See "String Programming Guide for Cocoa" for details on these options.
**/
- (NSComparisonResult)compareByName:(XMPPUserMemoryStorage *)another options:(NSStringCompareOptions)mask
{
	NSString *myName = [self displayName];
	NSString *theirName = [another displayName];
	
	return [myName compare:theirName options:mask];
}

/**
 * Returns the result of invoking compareByAvailabilityName:options: with no options.
**/
- (NSComparisonResult)compareByAvailabilityName:(XMPPUserMemoryStorage *)another
{
	return [self compareByAvailabilityName:another options:0];
}

/**
 * This method compares the two users according to availability first, and then display name.
 * Thus available users come before unavailable users.
 * If both users are available, or both users are not available,
 * this method follows the same functionality as the compareByName:options: as documented above.
**/
- (NSComparisonResult)compareByAvailabilityName:(XMPPUserMemoryStorage *)another options:(NSStringCompareOptions)mask
{
	if ([self isOnline])
	{
		if ([another isOnline])
			return [self compareByName:another options:mask];
		else
			return NSOrderedAscending;
	}
	else
	{
		if ([another isOnline])
			return NSOrderedDescending;
		else
			return [self compareByName:another options:mask];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark NSObject Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSUInteger)hash
{
	return [jid hash];
}

- (BOOL)isEqual:(id)anObject
{
	if ([anObject isMemberOfClass:[self class]])
	{
		XMPPUserMemoryStorage *another = (XMPPUserMemoryStorage *)anObject;
		
		return [jid isEqualToJID:[another jid]];
	}
	
	return NO;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<XMPPUser[%p]: %@>", self, [jid bare]];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark KVO Compliance methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (NSSet *)keyPathsForValuesAffectingIsOnline
{
    return [NSSet setWithObject:@"primaryResource"];
}

+ (NSSet *)keyPathsForValuesAffectingAllResources {
    return [NSSet setWithObject:@"resources"];
}

@end
