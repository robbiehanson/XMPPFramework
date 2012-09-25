#import "XMPP.h"
#import "XMPPRosterPrivate.h"
#import "XMPPRosterMemoryStorage.h"
#import "XMPPRosterMemoryStoragePrivate.h"
#import "XMPPLogging.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

/**
 * Does ARC support support GCD objects?
 * It does if the minimum deployment target is iOS 6+ or Mac OS X 10.8+
**/
#if TARGET_OS_IPHONE

  // Compiling for iOS

  #if __IPHONE_OS_VERSION_MIN_REQUIRED >= 60000 // iOS 6.0 or later
    #define NEEDS_DISPATCH_RETAIN_RELEASE 0
  #else                                         // iOS 5.X or earlier
    #define NEEDS_DISPATCH_RETAIN_RELEASE 1
  #endif

#else

  // Compiling for Mac OS X

  #if MAC_OS_X_VERSION_MIN_REQUIRED >= 1080     // Mac OS X 10.8 or later
    #define NEEDS_DISPATCH_RETAIN_RELEASE 0
  #else
    #define NEEDS_DISPATCH_RETAIN_RELEASE 1     // Mac OS X 10.7 or earlier
  #endif

#endif

// Log levels: off, error, warn, info, verbose
#if DEBUG
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN; // | XMPP_LOG_FLAG_TRACE;
#else
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

#define AssertPrivateQueue() \
        NSAssert(dispatch_get_current_queue() == parentQueue, @"Private method: MUST run on parentQueue");

#define AssertParentQueue() \
        NSAssert(dispatch_get_current_queue() == parentQueue, @"Private protocol method: MUST run on parentQueue");

@interface XMPPRosterMemoryStorage ()

@property (readonly) dispatch_queue_t parentQueue;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPRosterMemoryStorage

- (id)init
{
	if ((self = [super init]))
	{
		userClass = [XMPPUserMemoryStorageObject class];
		resourceClass = [XMPPResourceMemoryStorageObject class];
		
		roster = [[NSMutableDictionary alloc] init];
	}
	return self;
}

- (BOOL)configureWithParent:(XMPPRoster *)aParent queue:(dispatch_queue_t)queue
{
	NSParameterAssert(aParent != nil);
	NSParameterAssert(queue != NULL);
	
	@synchronized(self)
	{
		if ((parent == nil) && (parentQueue == NULL))
		{
			parent = aParent;
			parentQueue = queue;
			
			#if NEEDS_DISPATCH_RETAIN_RELEASE
			dispatch_retain(parentQueue);
			#endif
			
			return YES;
		}
	}
	
	return NO;
}

- (void)dealloc
{
	#if NEEDS_DISPATCH_RETAIN_RELEASE
	if (parentQueue)
		dispatch_release(parentQueue);
	#endif
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Properties
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@synthesize userClass;
@synthesize resourceClass;

- (XMPPRoster *)parent
{
	XMPPRoster *result = nil;
	
	@synchronized(self) // synchronized with configureWithParent:queue:
	{
		result = parent;
	}
	
	return result;
}

- (dispatch_queue_t)parentQueue
{
	dispatch_queue_t result = NULL;
	
	@synchronized(self) // synchronized with configureWithParent:queue:
	{
		result = parentQueue;
	}
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Internal API
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (GCDMulticastDelegate <XMPPRosterMemoryStorageDelegate> *)multicastDelegate
{
	return (GCDMulticastDelegate <XMPPRosterMemoryStorageDelegate> *)[parent multicastDelegate];
}

- (XMPPUserMemoryStorageObject *)_userForJID:(XMPPJID *)jid
{
	AssertPrivateQueue();
	
	XMPPUserMemoryStorageObject *result = [roster objectForKey:[jid bareJID]];
	
	if (result)
	{
		return result;
	}
	
	XMPPJID *myBareJID = [myJID bareJID];
	XMPPJID *bareJID = [jid bareJID];
	
	if ([bareJID isEqualToJID:myBareJID])
	{
		return myUser;
	}
	
	return nil;
}

- (XMPPResourceMemoryStorageObject *)_resourceForJID:(XMPPJID *)jid
{
	AssertPrivateQueue();
	
	XMPPUserMemoryStorageObject *user = [self _userForJID:jid];
	return (XMPPResourceMemoryStorageObject *)[user resourceForJID:jid];
}

- (NSArray *)_unsortedUsers
{
	AssertPrivateQueue();
	
	return [roster allValues];
}

- (NSArray *)_unsortedAvailableUsers
{
	AssertPrivateQueue();
	
	NSArray *allUsers = [roster allValues];
	
	NSMutableArray *result = [NSMutableArray arrayWithCapacity:[allUsers count]];
	
	for (id <XMPPUser> user in allUsers)
	{
		if ([user isOnline])
		{
			[result addObject:user];
		}
	}
	
	return result;
}

- (NSArray *)_unsortedUnavailableUsers
{
	AssertPrivateQueue();
	
	NSArray *allUsers = [roster allValues];
	
	NSMutableArray *result = [NSMutableArray arrayWithCapacity:[allUsers count]];
	
	for (id <XMPPUser> user in allUsers)
	{
		if (![user isOnline])
		{
			[result addObject:user];
		}
	}
	
	return result;
}

- (NSArray *)_sortedUsersByName
{
	AssertPrivateQueue();
	
	return [[roster allValues] sortedArrayUsingSelector:@selector(compareByName:)];
}

- (NSArray *)_sortedUsersByAvailabilityName
{
	AssertPrivateQueue();
	
	return [[roster allValues] sortedArrayUsingSelector:@selector(compareByAvailabilityName:)];
}

- (NSArray *)_sortedAvailableUsersByName
{
	AssertPrivateQueue();
	
	return [[self _unsortedAvailableUsers] sortedArrayUsingSelector:@selector(compareByName:)];
}

- (NSArray *)_sortedUnavailableUsersByName
{
	AssertPrivateQueue();
	
	return [[self _unsortedUnavailableUsers] sortedArrayUsingSelector:@selector(compareByName:)];
}

- (NSArray *)_sortedResources:(BOOL)includeResourcesForMyUserExcludingMyself
{
	AssertPrivateQueue();
	
	// Add all the resouces from all the available users in the roster
	// 
	// Remember: There may be multiple resources per user
	
	NSArray *availableUsers = [self unsortedAvailableUsers];
	
	NSMutableArray *result = [NSMutableArray arrayWithCapacity:[availableUsers count]];
	
	for (id<XMPPUser> user in availableUsers)
	{
		[result addObjectsFromArray:[user allResources]];
	}
	
	if (includeResourcesForMyUserExcludingMyself)
	{
		// Now add all the available resources from our own user account (excluding ourselves)
		
		NSArray *myResources = [myUser allResources];
		
		for (id<XMPPResource> resource in myResources)
		{
			if (![myJID isEqualToJID:[resource jid]])
			{
				[result addObject:resource];
			}
		}
	}
	
	return [result sortedArrayUsingSelector:@selector(compare:)];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Roster Management
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (XMPPUserMemoryStorageObject *)myUser
{
	// This is a public method, so it may be invoked on any thread/queue.
	
	if (self.parentQueue == NULL)
	{
		// Haven't been attached to parent yet
		return nil;
	}
	
	if (dispatch_get_current_queue() == parentQueue)
	{
		return myUser;
	}
	else
	{
		__block XMPPUserMemoryStorageObject *result;
		
		dispatch_sync(parentQueue, ^{
			result = [myUser copy];
		});
		
		return result;
	}
}

- (XMPPResourceMemoryStorageObject *)myResource
{
	// This is a public method, so it may be invoked on any thread/queue.
	
	if (self.parentQueue == NULL)
	{
		// Haven't been attached to parent yet
		return nil;
	}
	
	if (dispatch_get_current_queue() == parentQueue)
	{
		return (XMPPResourceMemoryStorageObject *)[myUser resourceForJID:myJID];
	}
	else
	{
		__block XMPPResourceMemoryStorageObject *result;
		
		dispatch_sync(parentQueue, ^{
			XMPPResourceMemoryStorageObject *resource =
			    (XMPPResourceMemoryStorageObject *)[myUser resourceForJID:myJID];
			result = [resource copy];
		});
		
		return result;
	}
}

- (XMPPUserMemoryStorageObject *)userForJID:(XMPPJID *)jid
{
	// This is a public method, so it may be invoked on any thread/queue.
	
	if (self.parentQueue == NULL)
	{
		// Haven't been attached to parent yet
		return nil;
	}
	
	if (dispatch_get_current_queue() == parentQueue)
	{
		return [self _userForJID:jid];
	}
	else
	{
		__block XMPPUserMemoryStorageObject *result;
		
		dispatch_sync(parentQueue, ^{ @autoreleasepool {
			
			XMPPUserMemoryStorageObject *user = [self _userForJID:jid];
			result = [user copy];
			
		}});
		
		return result;
	}
}

- (XMPPResourceMemoryStorageObject *)resourceForJID:(XMPPJID *)jid
{
	// This is a public method, so it may be invoked on any thread/queue.
	
	if (self.parentQueue == NULL)
	{
		// Haven't been attached to parent yet
		return nil;
	}
	
	if (dispatch_get_current_queue() == parentQueue)
	{
		return [self _resourceForJID:jid];
	}
	else
	{
		__block XMPPResourceMemoryStorageObject *result;
		
		dispatch_sync(parentQueue, ^{ @autoreleasepool {
			
			XMPPResourceMemoryStorageObject *resource = [self _resourceForJID:jid];
			result = [resource copy];
			
		}});
		
		return result;
	}
}

- (NSArray *)sortedUsersByName
{
	// This is a public method, so it may be invoked on any thread/queue.
	
	if (self.parentQueue == NULL)
	{
		// Haven't been attached to parent yet
		return nil;
	}
	
	if (dispatch_get_current_queue() == parentQueue)
	{
		return [self _sortedUsersByName];
	}
	else
	{
		__block NSArray *result;
		
		dispatch_sync(parentQueue, ^{ @autoreleasepool {
			
			NSArray *temp = [self _sortedUsersByName];
			
			result = [[NSArray alloc] initWithArray:temp copyItems:YES];
			
		}});
		
		return result;
	}
}

- (NSArray *)sortedUsersByAvailabilityName
{
	// This is a public method, so it may be invoked on any thread/queue.
	
	if (self.parentQueue == NULL)
	{
		// Haven't been attached to parent yet
		return nil;
	}
	
	if (dispatch_get_current_queue() == parentQueue)
	{
		return [self _sortedUsersByAvailabilityName];
	}
	else
	{
		__block NSArray *result;
		
		dispatch_sync(parentQueue, ^{ @autoreleasepool {
			
			NSArray *temp = [self _sortedUsersByAvailabilityName];
			
			result = [[NSArray alloc] initWithArray:temp copyItems:YES];
			
		}});
		
		return result;
	}
}

- (NSArray *)sortedAvailableUsersByName
{
	// This is a public method, so it may be invoked on any thread/queue.
	
	if (self.parentQueue == NULL)
	{
		// Haven't been attached to parent yet
		return nil;
	}
	
	if (dispatch_get_current_queue() == parentQueue)
	{
		return [self _sortedAvailableUsersByName];
	}
	else
	{
		__block NSArray *result;
		
		dispatch_sync(parentQueue, ^{ @autoreleasepool {
			
			NSArray *temp = [self _sortedAvailableUsersByName];
			result = [[NSArray alloc] initWithArray:temp copyItems:YES];
			
		}});
		
		return result;
	}
}

- (NSArray *)sortedUnavailableUsersByName
{
	// This is a public method, so it may be invoked on any thread/queue.
	
	if (self.parentQueue == NULL)
	{
		// Haven't been attached to parent yet
		return nil;
	}
	
	if (dispatch_get_current_queue() == parentQueue)
	{
		return [self _sortedUnavailableUsersByName];
	}
	else
	{
		__block NSArray *result;
		
		dispatch_sync(parentQueue, ^{ @autoreleasepool {
			
			NSArray *temp = [self _sortedUnavailableUsersByName];
			result = [[NSArray alloc] initWithArray:temp copyItems:YES];
			
		}});
		
		return result;
	}
}

- (NSArray *)unsortedUsers
{
	// This is a public method, so it may be invoked on any thread/queue.
	
	if (self.parentQueue == NULL)
	{
		// Haven't been attached to parent yet
		return nil;
	}
	
	if (dispatch_get_current_queue() == parentQueue)
	{
		return [self _unsortedUsers];
	}
	else
	{
		__block NSArray *result;
		
		dispatch_sync(parentQueue, ^{ @autoreleasepool {
			
			NSArray *temp = [self _unsortedUsers];
			result = [[NSArray alloc] initWithArray:temp copyItems:YES];
			
		}});
		
		return result;
	}
}

- (NSArray *)unsortedAvailableUsers
{
	// This is a public method, so it may be invoked on any thread/queue.
	
	if (self.parentQueue == NULL)
	{
		// Haven't been attached to parent yet
		return nil;
	}
	
	if (dispatch_get_current_queue() == parentQueue)
	{
		return [self _unsortedAvailableUsers];
	}
	else
	{
		__block NSArray *result;
		
		dispatch_sync(parentQueue, ^{ @autoreleasepool {
			
			NSArray *temp = [self _unsortedAvailableUsers];
			result = [[NSArray alloc] initWithArray:temp copyItems:YES];
			
		}});
		
		return result;
	}
}

- (NSArray *)unsortedUnavailableUsers
{
	// This is a public method, so it may be invoked on any thread/queue.
	
	if (self.parentQueue == NULL)
	{
		// Haven't been attached to parent yet
		return nil;
	}
	
	if (dispatch_get_current_queue() == parentQueue)
	{
		return [self _unsortedUnavailableUsers];
	}
	else
	{
		__block NSArray *result;
		
		dispatch_sync(parentQueue, ^{ @autoreleasepool {
			
			NSArray *temp = [self _unsortedUnavailableUsers];
			result = [[NSArray alloc] initWithArray:temp copyItems:YES];
			
		}});
		
		return result;
	}
}

- (NSArray *)sortedResources:(BOOL)includeResourcesForMyUserExcludingMyself
{
	// This is a public method, so it may be invoked on any thread/queue.
	
	if (self.parentQueue == NULL)
	{
		// Haven't been attached to parent yet
		return nil;
	}
	
	if (dispatch_get_current_queue() == parentQueue)
	{
		return [self _sortedResources:includeResourcesForMyUserExcludingMyself];
	}
	else
	{
		__block NSArray *result;
		
		dispatch_sync(parentQueue, ^{ @autoreleasepool {
			
			NSArray *temp = [self _sortedResources:includeResourcesForMyUserExcludingMyself];
			result = [[NSArray alloc] initWithArray:temp copyItems:YES];
			
		}});
		
		return result;
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPRosterStorage Protocol
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)beginRosterPopulationForXMPPStream:(XMPPStream *)stream
{
	XMPPLogTrace();
	AssertParentQueue();
	
	isRosterPopulation = YES;
	
	myJID = self.parent.xmppStream.myJID;
	
	myUser = [[self.userClass alloc] initWithJID:myJID];
}

- (void)endRosterPopulationForXMPPStream:(XMPPStream *)stream
{
	XMPPLogTrace();
	AssertParentQueue();
	
	isRosterPopulation = NO;
	
	[[self multicastDelegate] xmppRosterDidPopulate:self]; 
	[[self multicastDelegate] xmppRosterDidChange:self];
}

- (void)handleRosterItem:(NSXMLElement *)item xmppStream:(XMPPStream *)stream
{
	XMPPLogTrace();
	AssertParentQueue();
	
	NSString *jidStr = [item attributeStringValueForName:@"jid"];
	XMPPJID *jid = [[XMPPJID jidWithString:jidStr] bareJID];
	
	if (isRosterPopulation)
	{
		XMPPUserMemoryStorageObject *newUser =
		    (XMPPUserMemoryStorageObject *)[[self.userClass alloc] initWithItem:item];
		
		[roster setObject:newUser forKey:jid];
		
		XMPPLogVerbose(@"roster(%lu): %@", (unsigned long)[roster count], roster);
	}
	else
	{
		NSString *subscription = [item attributeStringValueForName:@"subscription"];
		
		if ([subscription isEqualToString:@"remove"])
		{
			XMPPUserMemoryStorageObject *user = [roster objectForKey:jid];
			if (user)
			{
				[roster removeObjectForKey:jid];
				
				XMPPLogVerbose(@"roster(%lu): %@", (unsigned long)[roster count], roster);
				
				[[self multicastDelegate] xmppRoster:self didRemoveUser:user];
				[[self multicastDelegate] xmppRosterDidChange:self];
			}
		}
		else
		{
			XMPPUserMemoryStorageObject *user = [roster objectForKey:jid];
			if (user)
			{
				[user updateWithItem:item];
				
				XMPPLogVerbose(@"roster(%lu): %@", (unsigned long)[roster count], roster);
				
				[[self multicastDelegate] xmppRoster:self didUpdateUser:user];
				[[self multicastDelegate] xmppRosterDidChange:self];
			}
			else
			{
				XMPPUserMemoryStorageObject *newUser =
				    (XMPPUserMemoryStorageObject *)[[self.userClass alloc] initWithItem:item];
				
				[roster setObject:newUser forKey:jid];
				
				XMPPLogVerbose(@"roster(%lu): %@", (unsigned long)[roster count], roster);
				
				[[self multicastDelegate] xmppRoster:self didAddUser:newUser];
				[[self multicastDelegate] xmppRosterDidChange:self];
				
			}
		}
	}
}

- (void)handlePresence:(XMPPPresence *)presence xmppStream:(XMPPStream *)stream
{
	XMPPLogTrace();
	AssertParentQueue();
	
	int change = XMPP_USER_NO_CHANGE;
	
	XMPPUserMemoryStorageObject *user = nil;
	XMPPResourceMemoryStorageObject *resource = nil;
	
	XMPPJID *jidKey = [[presence from] bareJID];
	
	user = [roster objectForKey:jidKey];
	if (user == nil)
	{
		// Not a presence element from anyone in our roster (that we know of).
		
		if ([[myJID bareJID] isEqualToJID:jidKey])
		{
			// It's a presence element for our user, either our resource or another resource.
			
			user = myUser;
		}
		else
		{
			// Unknown user (this is the first time we've encountered them).
			// This happens if the roster is in rosterlessOperation mode.
			
			user = (XMPPUserMemoryStorageObject *)[[self.userClass alloc] initWithJID:jidKey];
			
			[roster setObject:user forKey:jidKey];
			
			[[self multicastDelegate] xmppRoster:self didAddUser:user];
			[[self multicastDelegate] xmppRosterDidChange:self];
		}
	}
	
	change = [user updateWithPresence:presence resourceClass:self.resourceClass andGetResource:&resource];
	
	XMPPLogVerbose(@"roster(%lu): %@", (unsigned long)[roster count], roster);
	
	if (change == XMPP_USER_ADDED_RESOURCE)
		[[self multicastDelegate] xmppRoster:self didAddResource:resource withUser:user];
	
	if (change == XMPP_USER_UPDATED_RESOURCE)
		[[self multicastDelegate] xmppRoster:self didUpdateResource:resource withUser:user];
	
	if (change == XMPP_USER_REMOVED_RESOURCE)
		[[self multicastDelegate] xmppRoster:self didRemoveResource:resource withUser:user];
	
	if (change != XMPP_USER_NO_CHANGE)
		[[self multicastDelegate] xmppRosterDidChange:self];
}

- (BOOL)userExistsWithJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream
{
	XMPPLogTrace();
	AssertParentQueue();
	
	XMPPJID *jidKey = [jid bareJID];
	XMPPUserMemoryStorageObject *rosterUser = [roster objectForKey:jidKey];
	
	return (rosterUser != nil);
}

#if TARGET_OS_IPHONE
- (void)setPhoto:(UIImage *)photo forUserWithJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream
#else
- (void)setPhoto:(NSImage *)photo forUserWithJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream
#endif
{
	XMPPLogTrace();
	AssertParentQueue();
	
	XMPPJID *jidKey = [jid bareJID];
	XMPPUserMemoryStorageObject *rosterUser = [roster objectForKey:jidKey];
	
	if (rosterUser)
	{
		[rosterUser setPhoto:photo];
	}
}

- (void)clearAllResourcesForXMPPStream:(XMPPStream *)stream
{
	XMPPLogTrace();
	AssertParentQueue();
	
	for (XMPPUserMemoryStorageObject *user in [roster objectEnumerator])
	{
		[user clearAllResources];
	}
	
	[[self multicastDelegate] xmppRosterDidChange:self];
}

- (void)clearAllUsersAndResourcesForXMPPStream:(XMPPStream *)stream
{
	XMPPLogTrace();
	AssertParentQueue();
	
	[roster removeAllObjects];
	
	myUser = nil;
	
	[[self multicastDelegate] xmppRosterDidChange:self];
}

@end
