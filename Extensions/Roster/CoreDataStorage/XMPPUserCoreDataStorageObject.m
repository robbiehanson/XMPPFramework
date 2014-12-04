#import "XMPP.h"
#import "XMPPRosterCoreDataStorage.h"
#import "XMPPUserCoreDataStorageObject.h"
#import "XMPPResourceCoreDataStorageObject.h"
#import "XMPPGroupCoreDataStorageObject.h"
#import "NSNumber+XMPP.h"
#import "XMPPLogging.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

// Log levels: off, error, warn, info, verbose
#if DEBUG
static const int xmppLogLevel = XMPP_LOG_LEVEL_INFO; // | XMPP_LOG_FLAG_TRACE;
#else
static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

@interface XMPPUserCoreDataStorageObject ()

@property(nonatomic,strong) XMPPJID *primitiveJid;
@property(nonatomic,strong) NSString *primitiveJidStr;

@property(nonatomic,strong) NSString *primitiveDisplayName;
@property(nonatomic,assign) NSInteger primitiveSection;
@property(nonatomic,strong) NSString *primitiveSectionName;
@property(nonatomic,strong) NSNumber *primitiveSectionNum;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPUserCoreDataStorageObject

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Accessors
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


@dynamic jid, primitiveJid;
@dynamic jidStr, primitiveJidStr;
@dynamic streamBareJidStr;

@dynamic nickname;
@dynamic displayName, primitiveDisplayName;
@dynamic subscription;
@dynamic ask;
@dynamic unreadMessages;
@dynamic photo;

@dynamic section, primitiveSection;
@dynamic sectionName, primitiveSectionName;
@dynamic sectionNum, primitiveSectionNum;

@dynamic groups;
@dynamic primaryResource;
@dynamic resources;

- (XMPPJID *)jid
{
  // Create and cache the jid on demand
  
  [self willAccessValueForKey:@"jid"];
  XMPPJID *tmp = [self primitiveJid];
  [self didAccessValueForKey:@"jid"];
  
  if (tmp == nil) {
    tmp = [XMPPJID jidWithString:[self jidStr]];

    [self setPrimitiveJid:tmp];
  }
  return tmp;
}

- (void)setJid:(XMPPJID *)jid
{
	self.jidStr = [jid bare];
}

- (void)setJidStr:(NSString *)jidStr
{  
  [self willChangeValueForKey:@"jidStr"];
  [self setPrimitiveJidStr:jidStr];
  [self didChangeValueForKey:@"jidStr"];
  
  // If the jidStr changes, the jid becomes invalid.
  [self setPrimitiveJid:nil];
}

- (NSInteger)section
{
  // Create and cache the section on demand
  [self willAccessValueForKey:@"section"];
  NSInteger tmp = [self primitiveSection];
  [self didAccessValueForKey:@"section"];
  
  // section uses zero, so to distinguish unset values, use NSNotFound
  if (tmp == NSNotFound) {
    tmp = [[self sectionNum] integerValue];
    
    [self setPrimitiveSection:tmp];
  }
  return tmp;
}

- (void)setSection:(NSInteger)value
{
	self.sectionNum = [NSNumber numberWithInteger:value];
}

- (NSInteger)primitiveSection
{
  return section;
}

- (void)setPrimitiveSection:(NSInteger)primitiveSection
{
  section = primitiveSection;
}



- (void)setSectionNum:(NSNumber *)sectionNum
{
  [self willChangeValueForKey:@"sectionNum"];
  [self setPrimitiveSectionNum:sectionNum];
  [self didChangeValueForKey:@"sectionNum"];
  
  // If the sectionNum changes, the section becomes invalid.
  // section uses zero, so to distinguish unset values, use NSNotFound
  [self setPrimitiveSection:NSNotFound];
}

- (NSString *)sectionName
{
  // Create and cache the sectionName on demand
  
  [self willAccessValueForKey:@"sectionName"];
  NSString *tmp = [self primitiveSectionName];
  [self didAccessValueForKey:@"sectionName"];
  
  if (tmp == nil) {
    // Section names are organized by capitalizing the first letter of the displayName
    
    NSString *upperCase = [self.displayName uppercaseString];
    
    // return the first character with support UTF-16:
    tmp = [upperCase substringWithRange:[upperCase rangeOfComposedCharacterSequenceAtIndex:0]];

    [self setPrimitiveSectionName:tmp];
  }
  return tmp;
}

- (void)setDisplayName:(NSString *)displayName
{  
  [self willChangeValueForKey:@"displayName"];
  [self setPrimitiveDisplayName:displayName];
  [self didChangeValueForKey:@"displayName"];
  
  // If the displayName changes, the sectionName becomes invalid.
  [self setPrimitiveSectionName:nil];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark NSManagedObject
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)awakeFromInsert
{
	// Section uses zero, so to distinguish unset values, use NSNotFound.
	
	self.primitiveSection = NSNotFound;
}

- (void)awakeFromFetch
{
	// Section uses zero, so to distinguish unset values, use NSNotFound.
	// 
	// Note: Do NOT use "self.section = NSNotFound" as this will in turn set the sectionNum.
	
	self.primitiveSection = NSNotFound;
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Creation & Updates
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (id)insertInManagedObjectContext:(NSManagedObjectContext *)moc
                           withJID:(XMPPJID *)jid
                  streamBareJidStr:(NSString *)streamBareJidStr
{
	if (jid == nil)
	{
		XMPPLogVerbose(@"XMPPUserCoreDataStorageObject: invalid jid (nil)");
		return nil;
	}
	
	XMPPUserCoreDataStorageObject *newUser;
	newUser = [NSEntityDescription insertNewObjectForEntityForName:@"XMPPUserCoreDataStorageObject"
	                                        inManagedObjectContext:moc];
	
	newUser.streamBareJidStr = streamBareJidStr;
	
	newUser.jid = jid;
	newUser.nickname = nil;
	
	newUser.displayName = [jid bare];
	
	return newUser;
}

+ (id)insertInManagedObjectContext:(NSManagedObjectContext *)moc
                          withItem:(NSXMLElement *)item
                  streamBareJidStr:(NSString *)streamBareJidStr
{
	NSString *jidStr = [item attributeStringValueForName:@"jid"];
	XMPPJID *jid = [XMPPJID jidWithString:jidStr];
	
	if (jid == nil)
	{
		XMPPLogVerbose(@"XMPPUserCoreDataStorageObject: invalid item (missing or invalid jid): %@", item);
		return nil;
	}
	
	XMPPUserCoreDataStorageObject *newUser;
	newUser = [NSEntityDescription insertNewObjectForEntityForName:@"XMPPUserCoreDataStorageObject"
	                                        inManagedObjectContext:moc];
	
	newUser.streamBareJidStr = streamBareJidStr;
	
	[newUser updateWithItem:item];
	
	return newUser;
}

- (void)updateGroupsWithItem:(NSXMLElement *)item
{
	XMPPGroupCoreDataStorageObject *group = nil;

	// clear existing group memberships first
	if ([self.groups count] > 0) {
		[self removeGroups:self.groups];
	}

	NSArray *groupItems = [item elementsForName:@"group"];
	NSString *groupName = nil;

	for (NSXMLElement *groupElement in groupItems) {
		groupName = [groupElement stringValue];

		group = [XMPPGroupCoreDataStorageObject fetchOrInsertGroupName:groupName 
		                                        inManagedObjectContext:[self managedObjectContext]];

		if (group != nil) {
			[self addGroupsObject:group];
		}
	}
}

- (void)updateWithItem:(NSXMLElement *)item
{
	NSString *jidStr = [item attributeStringValueForName:@"jid"];
	XMPPJID *jid = [XMPPJID jidWithString:jidStr];
	
	if (jid == nil)
	{
		XMPPLogVerbose(@"XMPPUserCoreDataStorageObject: invalid item (missing or invalid jid): %@", item);
		return;
	}
	
	self.jid = jid;
	self.nickname = [item attributeStringValueForName:@"name"];
	
	self.displayName = self.nickname ? : jidStr;
	
	self.subscription = [item attributeStringValueForName:@"subscription"];
	self.ask = [item attributeStringValueForName:@"ask"];
	
	[self updateGroupsWithItem:item];
}

- (void)recalculatePrimaryResource
{
	self.primaryResource = nil;
	
	NSArray *sortedResources = [[self allResources] sortedArrayUsingSelector:@selector(compare:)];
	if ([sortedResources count] > 0)
	{
		XMPPResourceCoreDataStorageObject *resource = [sortedResources objectAtIndex:0];
		
		// Primary resource must have a non-negative priority
		if ([resource priority] >= 0)
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

- (void)updateWithPresence:(XMPPPresence *)presence streamBareJidStr:(NSString *)streamBareJidStr
{
	XMPPResourceCoreDataStorageObject *resource =
	    (XMPPResourceCoreDataStorageObject *)[self resourceForJID:[presence from]];
	
	if ([[presence type] isEqualToString:@"unavailable"] || [presence isErrorPresence])
	{
		if (resource)
		{
			[self removeResourcesObject:resource];
			[[self managedObjectContext] deleteObject:resource];
		}
	}
	else
	{
		if (resource)
		{
			[resource updateWithPresence:presence];
		}
		else
		{
			XMPPResourceCoreDataStorageObject *newResource;
			newResource = [XMPPResourceCoreDataStorageObject insertInManagedObjectContext:[self managedObjectContext]
			                                                           withPresence:presence
			                                                       streamBareJidStr:streamBareJidStr];
			
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
	
	for (XMPPResourceCoreDataStorageObject *resource in [self resources])
	{
		if ([jidStr isEqualToString:[resource jidStr]])
		{
			return resource;
		}
	}
	
	return nil;
}

- (NSArray *)allResources
{
    NSMutableArray *allResources = [NSMutableArray array];
	
    for (XMPPResourceCoreDataStorageObject *resource in [[self resources] allObjects]) {
        
        if(![resource isDeleted])
        {
            [allResources addObject:resource];
        }
    }
    
    return allResources;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Comparisons
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Returns the result of invoking compareByName:options: with no options.
**/
- (NSComparisonResult)compareByName:(XMPPUserCoreDataStorageObject *)another
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
- (NSComparisonResult)compareByName:(XMPPUserCoreDataStorageObject *)another options:(NSStringCompareOptions)mask
{
	NSString *myName = [self displayName];
	NSString *theirName = [another displayName];
	
	return [myName compare:theirName options:mask];
}

/**
 * Returns the result of invoking compareByAvailabilityName:options: with no options.
**/
- (NSComparisonResult)compareByAvailabilityName:(XMPPUserCoreDataStorageObject *)another
{
	return [self compareByAvailabilityName:another options:0];
}

/**
 * This method compares the two users according to availability first, and then display name.
 * Thus available users come before unavailable users.
 * If both users are available, or both users are not available,
 * this method follows the same functionality as the compareByName:options: as documented above.
**/
- (NSComparisonResult)compareByAvailabilityName:(XMPPUserCoreDataStorageObject *)another
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
#pragma mark KVO compliance methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (NSSet *)keyPathsForValuesAffectingJid {
	// If the jidStr changes, the jid may change as well.
	return [NSSet setWithObject:@"jidStr"];
}

+ (NSSet *)keyPathsForValuesAffectingIsOnline {
	return [NSSet setWithObject:@"primaryResource"];
}

+ (NSSet *)keyPathsForValuesAffectingSection {
	// If the value of sectionNum changes, the section may change as well.
	return [NSSet setWithObject:@"sectionNum"];
}

+ (NSSet *)keyPathsForValuesAffectingSectionName {
	// If the value of displayName changes, the sectionName may change as well.
	return [NSSet setWithObject:@"displayName"];
}

+ (NSSet *)keyPathsForValuesAffectingAllResources {
	return [NSSet setWithObject:@"resources"];
}

@end
