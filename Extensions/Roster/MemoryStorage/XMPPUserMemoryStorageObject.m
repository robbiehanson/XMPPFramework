#import "XMPP.h"
#import "XMPPRosterMemoryStoragePrivate.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

@interface XMPPUserMemoryStorageObject (PrivateAPI)
- (void)recalculatePrimaryResource;
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPUserMemoryStorageObject

- (void)commonInit
{
	// This method is here to more easily support subclassing.
	// That way subclasses can optionally override just commonInit, instead of each individual init method.
	// 
	// If you override this method, don't forget to invoke [super commonInit];
	
	resources = [[NSMutableDictionary alloc] initWithCapacity:1];
}

- (id)initWithJID:(XMPPJID *)aJid
{
	if ((self = [super init]))
	{
		jid = [aJid bareJID];
		
		itemAttributes = [[NSMutableDictionary alloc] initWithCapacity:0];
		
		[self commonInit];
	}
	return self;
}

- (id)initWithItem:(NSXMLElement *)item
{
	if ((self = [super init]))
	{
		NSString *jidStr = [item attributeStringValueForName:@"jid"];
		jid = [[XMPPJID jidWithString:jidStr] bareJID];
		
		itemAttributes = [item attributesAsDictionary];
		
		[self commonInit];
	}
	return self;
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Copying
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (id)copyWithZone:(NSZone *)zone
{
	// We use [self class] to support subclassing
	
	XMPPUserMemoryStorageObject *deepCopy = (XMPPUserMemoryStorageObject *)[[[self class] alloc] init];
	
	deepCopy->jid = [jid copy];
	deepCopy->itemAttributes = [itemAttributes mutableCopy];
	
	deepCopy->resources = [[NSMutableDictionary alloc] initWithCapacity:[resources count]];
	
	for (XMPPJID *key in resources)
	{
		XMPPResourceMemoryStorageObject *resourceCopy = [[resources objectForKey:key] copy];
		
		[deepCopy->resources setObject:resourceCopy forKey:key];
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
			jid             = [coder decodeObjectForKey:@"jid"];
			itemAttributes  = [[coder decodeObjectForKey:@"itemAttributes"] mutableCopy];
		#if TARGET_OS_IPHONE
			photo           = [[UIImage alloc] initWithData:[coder decodeObjectForKey:@"photo"]];
		#else
			photo           = [[NSImage alloc] initWithData:[coder decodeObjectForKey:@"photo"]];
		#endif
			resources       = [[coder decodeObjectForKey:@"resources"] mutableCopy];
			primaryResource = [coder decodeObjectForKey:@"primaryResource"];
		}
		else
		{
			jid             = [coder decodeObject];
			itemAttributes  = [[coder decodeObject] mutableCopy];
		#if TARGET_OS_IPHONE
			photo           = [[UIImage alloc] initWithData:[coder decodeObject]];
		#else
			photo           = [[NSImage alloc] initWithData:[coder decodeObject]];
		#endif	
			resources       = [[coder decodeObject] mutableCopy];
			primaryResource = [coder decodeObject];
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
#pragma mark Hooks
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)didAddResource:(XMPPResourceMemoryStorageObject *)resource withPresence:(XMPPPresence *)presence
{
	// Override / customization hook
}

- (void)willUpdateResource:(XMPPResourceMemoryStorageObject *)resource withPresence:(XMPPPresence *)presence
{
	// Override / customization hook
}

- (void)didUpdateResource:(XMPPResourceMemoryStorageObject *)resource withPresence:(XMPPPresence *)presence
{
	// Override / customization hook
}

- (void)didRemoveResource:(XMPPResourceMemoryStorageObject *)resource withPresence:(XMPPPresence *)presence
{
	// Override / customization hook
}

- (void)recalculatePrimaryResource
{
	// Override me to customize how the primary resource is chosen.
	// 
	// This method uses the [XMPPResourceMemoryStorage compare:] method to sort the resources,
	// and properly supports negative (bot) priorities.
	
	primaryResource = nil;
	
	NSArray *sortedResources = [[self allResources] sortedArrayUsingSelector:@selector(compare:)];
	if ([sortedResources count] > 0)
	{
		XMPPResourceMemoryStorageObject *possiblePrimary = [sortedResources objectAtIndex:0];
		
		// Primary resource must have a non-negative priority
		if ([[possiblePrimary presence] priority] >= 0)
		{
			primaryResource = possiblePrimary;
		}
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Update Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)clearAllResources
{
	[resources removeAllObjects];
	
	primaryResource = nil;
}

- (void)updateWithItem:(NSXMLElement *)item
{
	[itemAttributes removeAllObjects];
	
	for (NSXMLNode *node in [item attributes])
	{
		NSString *key   = [node name];
		NSString *value = [node stringValue];
		
		[itemAttributes setObject:value forKey:key];
	}
}

- (int)updateWithPresence:(XMPPPresence *)presence
            resourceClass:(Class)resourceClass
           andGetResource:(XMPPResourceMemoryStorageObject **)resourcePtr
{
	int result = XMPP_USER_NO_CHANGE;
	XMPPResourceMemoryStorageObject *resource;
	
	XMPPJID *key = [presence from];
	NSString *presenceType = [presence type];
	
	if ([presenceType isEqualToString:@"unavailable"] || [presenceType isEqualToString:@"error"])
	{
		resource = [resources objectForKey:key];
		if (resource)
		{
			[resources removeObjectForKey:key];
			[self didRemoveResource:resource withPresence:presence];
			
			result = XMPP_USER_REMOVED_RESOURCE;
		}
	}
	else
	{
		resource = [resources objectForKey:key];
		if (resource)
		{
			[self willUpdateResource:resource withPresence:presence];
			[resource updateWithPresence:presence];
			[self didUpdateResource:resource withPresence:presence];
			
			result = XMPP_USER_UPDATED_RESOURCE;
		}
		else
		{
			resource = (XMPPResourceMemoryStorageObject *)[[resourceClass alloc] initWithPresence:presence];
			
			[resources setObject:resource forKey:key];
			[self didAddResource:resource withPresence:presence];
			
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
- (NSComparisonResult)compareByName:(XMPPUserMemoryStorageObject *)another
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
- (NSComparisonResult)compareByName:(XMPPUserMemoryStorageObject *)another options:(NSStringCompareOptions)mask
{
	NSString *myName = [self displayName];
	NSString *theirName = [another displayName];
	
	return [myName compare:theirName options:mask];
}

/**
 * Returns the result of invoking compareByAvailabilityName:options: with no options.
**/
- (NSComparisonResult)compareByAvailabilityName:(XMPPUserMemoryStorageObject *)another
{
	return [self compareByAvailabilityName:another options:0];
}

/**
 * This method compares the two users according to availability first, and then display name.
 * Thus available users come before unavailable users.
 * If both users are available, or both users are not available,
 * this method follows the same functionality as the compareByName:options: as documented above.
**/
- (NSComparisonResult)compareByAvailabilityName:(XMPPUserMemoryStorageObject *)another
                                        options:(NSStringCompareOptions)mask
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
		XMPPUserMemoryStorageObject *another = (XMPPUserMemoryStorageObject *)anObject;
		
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
