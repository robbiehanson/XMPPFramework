#import "XMPP.h"
#import "XMPPRosterCoreDataStorage.h"
#import "XMPPUserCoreDataStorage.h"
#import "XMPPResourceCoreDataStorage.h"

@interface XMPPUserCoreDataStorage (CoreDataGeneratedPrimitiveAccessors)
- (NSString *)primitiveNickname;
- (NSString *)primitiveDisplayName;
- (XMPPResourceCoreDataStorage *)primitivePrimaryResource;
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPUserCoreDataStorage

@dynamic jid;     // Implementation below
@dynamic section; // Implementation below

@dynamic jidStr;
@dynamic nickname;
@dynamic displayName;
@dynamic subscription;
@dynamic ask;

@dynamic sectionNum;

@dynamic primaryResource;
@dynamic resources;

- (XMPPJID *)jid
{
	return [XMPPJID jidWithString:[self jidStr]];
}

- (void)setJid:(XMPPJID *)jid
{
	self.jidStr = [jid bare];
}

- (int)section
{
	return [[self sectionNum] intValue];
}

- (void)setSection:(int)value
{
	self.sectionNum = [NSNumber numberWithInt:value];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Compiler Workarounds
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#if TARGET_OS_IPHONE && !TARGET_IPHONE_SIMULATOR

/**
 * This method is here to quiet the compiler.
 * Without it the compiler complains that this method is not implemented as required by the protocol.
 * This only seems to be a problem when compiling for the device.
**/
- (NSString *)displayName 
{
    NSString * tmpValue;
    
    [self willAccessValueForKey:@"displayName"];
    tmpValue = [self primitiveDisplayName];
    [self didAccessValueForKey:@"displayName"];
    
    return tmpValue;
}

/**
 * This method is here to quiet the compiler.
 * Without it the compiler complains that this method is not implemented as required by the protocol.
 * This only seems to be a problem when compiling for the device.
**/
- (NSString *)nickname 
{
    NSString * tmpValue;
    
    [self willAccessValueForKey:@"nickname"];
    tmpValue = [self primitiveNickname];
    [self didAccessValueForKey:@"nickname"];
    
    return tmpValue;
}

/**
 * This method is here to quiet the compiler.
 * Without it the compiler complains that this method is not implemented as required by the protocol.
 * This only seems to be a problem when compiling for the device.
**/
- (XMPPResourceCoreDataStorage *)primaryResource 
{
    id tmpObject;
    
    [self willAccessValueForKey:@"primaryResource"];
    tmpObject = [self primitivePrimaryResource];
    [self didAccessValueForKey:@"primaryResource"];
    
    return tmpObject;
}

#endif

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Creation & Updates
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (id)insertInManagedObjectContext:(NSManagedObjectContext *)moc withItem:(NSXMLElement *)item
{
	NSString *jidStr = [item attributeStringValueForName:@"jid"];
	XMPPJID *jid = [XMPPJID jidWithString:jidStr];
	
	if (jid == nil)
	{
		NSLog(@"XMPPUserCoreDataStorage: invalid item (missing or invalid jid): %@", item);
		return nil;
	}
	
	XMPPUserCoreDataStorage *newUser;
	newUser = [NSEntityDescription insertNewObjectForEntityForName:@"XMPPUserCoreDataStorage"
	                                        inManagedObjectContext:moc];
	
	[newUser updateWithItem:item];
	
	return newUser;
}

- (void)updateWithItem:(NSXMLElement *)item
{
	NSString *jidStr = [item attributeStringValueForName:@"jid"];
	XMPPJID *jid = [XMPPJID jidWithString:jidStr];
	
	if (jid == nil)
	{
		NSLog(@"XMPPUserCoreDataStorage: invalid item (missing or invalid jid): %@", item);
		return;
	}
	
	self.jid = jid;
	self.nickname = [item attributeStringValueForName:@"name"];
	
	self.displayName = (self.nickname != nil) ? self.nickname : jidStr;
	
	self.subscription = [item attributeStringValueForName:@"subscription"];
	self.ask = [item attributeStringValueForName:@"ask"];
}

- (void)recalculatePrimaryResource
{
	self.primaryResource = nil;
	
	NSArray *sortedResources = [self sortedResources];
	if ([sortedResources count] > 0)
	{
		XMPPResourceCoreDataStorage *resource = [sortedResources objectAtIndex:0];
		
		// Primary resource must have a non-negative priority
		if([resource priority] >= 0)
		{
			self.primaryResource = resource;
			
			if (resource.intShow >= 3)
				self.section = 0;
			else
				self.section = 1;
		}
	}
	
	if (self.primaryResource == nil)
	{
		self.section = 2;
	}
}

- (void)updateWithPresence:(XMPPPresence *)presence
{
	XMPPResourceCoreDataStorage *resource = (XMPPResourceCoreDataStorage *)[self resourceForJID:[presence from]];
	
	if ([[presence type] isEqualToString:@"unavailable"])
	{
		if (resource)
		{
			[[self managedObjectContext] deleteObject:resource];
		}
	}
	else
	{
		if(resource)
		{
			[resource updateWithPresence:presence];
		}
		else
		{
			XMPPResourceCoreDataStorage *newResource;
			newResource = [XMPPResourceCoreDataStorage insertInManagedObjectContext:[self managedObjectContext]
			                                                           withPresence:presence];
			
			[self addResourcesObject:newResource];
		}
	}
	
	[self recalculatePrimaryResource];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPUser Protocol
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)isOnline
{
	return (self.primaryResource != nil);
}

- (BOOL)isPendingApproval
{
	// Either of the following mean we're waiting to have our presence subscription approved:
	// <item ask='subscribe' subscription='none' jid='robbiehanson@deusty.com'/>
	// <item ask='subscribe' subscription='from' jid='robbiehanson@deusty.com'/>
	
	NSString *subscription = self.subscription;
	NSString *ask = self.ask;
	
	if ([subscription isEqualToString:@"none"] || [subscription isEqualToString:@"from"])
	{
		if ([ask isEqualToString:@"subscribe"])
		{
			return YES;
		}
	}
	
	return NO;
}

- (id <XMPPResource>)resourceForJID:(XMPPJID *)jid
{
	NSString *jidStr = [jid full];
	
	for (XMPPResourceCoreDataStorage *resource in [self resources])
	{
		if ([jidStr isEqualToString:[resource jidStr]])
		{
			return resource;
		}
	}
	
	return nil;
}

- (NSArray *)sortedResources
{
	return [[self unsortedResources] sortedArrayUsingSelector:@selector(compare:)];
}

- (NSArray *)unsortedResources
{
	return [[self resources] allObjects];
}

/**
 * Returns the result of invoking compareByName:options: with no options.
**/
- (NSComparisonResult)compareByName:(id <XMPPUser>)another
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
- (NSComparisonResult)compareByName:(id <XMPPUser>)another options:(NSStringCompareOptions)mask
{
	NSString *myName = [self displayName];
	NSString *theirName = [another displayName];
	
	return [myName compare:theirName options:mask];
}

/**
 * Returns the result of invoking compareByAvailabilityName:options: with no options.
**/
- (NSComparisonResult)compareByAvailabilityName:(id <XMPPUser>)another
{
	return [self compareByAvailabilityName:another options:0];
}

/**
 * This method compares the two users according to availability first, and then display name.
 * Thus available users come before unavailable users.
 * If both users are available, or both users are not available,
 * this method follows the same functionality as the compareByName:options: as documented above.
**/
- (NSComparisonResult)compareByAvailabilityName:(id <XMPPUser>)another options:(NSStringCompareOptions)mask
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

@end
