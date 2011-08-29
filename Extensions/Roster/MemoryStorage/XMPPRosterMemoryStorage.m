#import "XMPP.h"
#import "XMPPRosterPrivate.h"
#import "XMPPRosterMemoryStorage.h"
#import "XMPPRosterMemoryStoragePrivate.h"
#import "XMPPLogging.h"

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

@property (assign, readwrite) XMPPRoster *parent;
@property (readwrite) dispatch_queue_t parentQueue;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPRosterMemoryStorage

- (id)init
{
	if ((self = [super init]))
	{
		userClass = [XMPPUserMemoryStorage class];
		resourceClass = [XMPPResourceMemoryStorage class];
		
		roster = [[NSMutableDictionary alloc] init];
	}
	return self;
}

- (BOOL)configureWithParent:(XMPPRoster *)aParent queue:(dispatch_queue_t)queue
{
	NSParameterAssert(aParent != nil);
	NSParameterAssert(queue != NULL);
	
	if ((parent == nil) && (parentQueue == NULL))
	{
		self.parent = aParent;
		self.parentQueue = queue;
		
		return YES;
	}
	
	return NO;
}

- (void)dealloc
{
	if (parentQueue)
		dispatch_release(parentQueue);
	
	[roster release];
	[myJID release];
	[myUser release];
	[super dealloc];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Properties
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@synthesize parent;
@synthesize userClass;
@synthesize resourceClass;

- (dispatch_queue_t)parentQueue
{
	dispatch_queue_t result = NULL;
	
	@synchronized(self)
	{
		result = parentQueue;
	}
	
	return result;
}

- (void)setParentQueue:(dispatch_queue_t)queue
{
	@synchronized(self)
	{
		if (parentQueue != queue)
		{
			if (parentQueue)
				dispatch_release(parentQueue);
			
			parentQueue = queue;
			dispatch_retain(parentQueue);
		}
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Internal API
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (GCDMulticastDelegate <XMPPRosterMemoryStorageDelegate> *)multicastDelegate
{
	return (GCDMulticastDelegate <XMPPRosterMemoryStorageDelegate> *)[parent multicastDelegate];
}

- (id <XMPPUser>)_userForJID:(XMPPJID *)jid
{
	AssertPrivateQueue();
	
	XMPPUserMemoryStorage *result = [roster objectForKey:[jid bareJID]];
	
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

- (id <XMPPResource>)_resourceForJID:(XMPPJID *)jid
{
	AssertPrivateQueue();
	
	XMPPUserMemoryStorage *user = (XMPPUserMemoryStorage *)[self _userForJID:jid];
	return [user resourceForJID:jid];
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

- (id <XMPPUser>)myUser
{
	// This is a public method, so it may be invoked on any thread/queue.
	
	if (self.parentQueue == nil)
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
		__block XMPPUserMemoryStorage *result;
		
		dispatch_sync(parentQueue, ^{
			result = [myUser copy];
		});
		
		return [result autorelease];
	}
}

- (id <XMPPResource>)myResource
{
	// This is a public method, so it may be invoked on any thread/queue.
	
	if (self.parentQueue == nil)
	{
		// Haven't been attached to parent yet
		return nil;
	}
	
	if (dispatch_get_current_queue() == parentQueue)
	{
		return [myUser resourceForJID:myJID];
	}
	else
	{
		__block XMPPResourceMemoryStorage *result;
		
		dispatch_sync(parentQueue, ^{
			XMPPResourceMemoryStorage *resource = (XMPPResourceMemoryStorage *)[myUser resourceForJID:myJID];
			result = [resource copy];
		});
		
		return [result autorelease];
	}
}

- (id <XMPPUser>)userForJID:(XMPPJID *)jid
{
	// This is a public method, so it may be invoked on any thread/queue.
	
	if (self.parentQueue == nil)
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
		__block XMPPUserMemoryStorage *result;
		
		dispatch_sync(parentQueue, ^{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			
			XMPPUserMemoryStorage *user = (XMPPUserMemoryStorage *)[self _userForJID:jid];
			result = [user copy];
			
			[pool release];
		});
		
		return [result autorelease];
	}
}

- (id <XMPPResource>)resourceForJID:(XMPPJID *)jid
{
	// This is a public method, so it may be invoked on any thread/queue.
	
	if (self.parentQueue == nil)
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
		__block XMPPResourceMemoryStorage *result;
		
		dispatch_sync(parentQueue, ^{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			
			XMPPResourceMemoryStorage *resource = (XMPPResourceMemoryStorage *)[self _resourceForJID:jid];
			result = [resource copy];
			
			[pool release];
		});
		
		return [result autorelease];
	}
}

- (NSArray *)sortedUsersByName
{
	// This is a public method, so it may be invoked on any thread/queue.
	
	if (self.parentQueue == nil)
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
		
		dispatch_sync(parentQueue, ^{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			
			NSArray *temp = [self _sortedUsersByName];
			
			result = [[NSArray alloc] initWithArray:temp copyItems:YES];
			
			[pool release];
		});
		
		return [result autorelease];
	}
}

- (NSArray *)sortedUsersByAvailabilityName
{
	// This is a public method, so it may be invoked on any thread/queue.
	
	if (self.parentQueue == nil)
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
		
		dispatch_sync(parentQueue, ^{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			
			NSArray *temp = [self _sortedUsersByAvailabilityName];
			
			result = [[NSArray alloc] initWithArray:temp copyItems:YES];
			
			[pool release];
		});
		
		return [result autorelease];
	}
}

- (NSArray *)sortedAvailableUsersByName
{
	// This is a public method, so it may be invoked on any thread/queue.
	
	if (self.parentQueue == nil)
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
		
		dispatch_sync(parentQueue, ^{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			
			NSArray *temp = [self _sortedAvailableUsersByName];
			
			result = [[NSArray alloc] initWithArray:temp copyItems:YES];
			
			[pool release];
		});
		
		return [result autorelease];
	}
}

- (NSArray *)sortedUnavailableUsersByName
{
	// This is a public method, so it may be invoked on any thread/queue.
	
	if (self.parentQueue == nil)
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
		
		dispatch_sync(parentQueue, ^{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			
			NSArray *temp = [self _sortedUnavailableUsersByName];
			
			result = [[NSArray alloc] initWithArray:temp copyItems:YES];
			
			[pool release];
		});
		
		return [result autorelease];
	}
}

- (NSArray *)unsortedUsers
{
	// This is a public method, so it may be invoked on any thread/queue.
	
	if (self.parentQueue == nil)
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
		
		dispatch_sync(parentQueue, ^{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			
			NSArray *temp = [self _unsortedUsers];
			
			result = [[NSArray alloc] initWithArray:temp copyItems:YES];
			
			[pool release];
		});
		
		return [result autorelease];
	}
}

- (NSArray *)unsortedAvailableUsers
{
	// This is a public method, so it may be invoked on any thread/queue.
	
	if (self.parentQueue == nil)
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
		
		dispatch_sync(parentQueue, ^{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			
			NSArray *temp = [self _unsortedAvailableUsers];
			
			result = [[NSArray alloc] initWithArray:temp copyItems:YES];
			
			[pool release];
		});
		
		return [result autorelease];
	}
}

- (NSArray *)unsortedUnavailableUsers
{
	// This is a public method, so it may be invoked on any thread/queue.
	
	if (self.parentQueue == nil)
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
		
		dispatch_sync(parentQueue, ^{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			
			NSArray *temp = [self _unsortedUnavailableUsers];
			
			result = [[NSArray alloc] initWithArray:temp copyItems:YES];
			
			[pool release];
		});
		
		return [result autorelease];
	}
}

- (NSArray *)sortedResources:(BOOL)includeResourcesForMyUserExcludingMyself
{
	// This is a public method, so it may be invoked on any thread/queue.
	
	if (self.parentQueue == nil)
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
		
		dispatch_sync(parentQueue, ^{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			
			NSArray *temp = [self _sortedResources:includeResourcesForMyUserExcludingMyself];
			
			result = [[NSArray alloc] initWithArray:temp copyItems:YES];
			
			[pool release];
		});
		
		return [result autorelease];
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
	
	[myJID release];
	myJID = [parent.xmppStream.myJID retain];
	
	[myUser release];
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
		XMPPUserMemoryStorage *newUser = (XMPPUserMemoryStorage *)[[self.userClass alloc] initWithItem:item];
		
		[roster setObject:newUser forKey:jid];
		[newUser release];
		
		XMPPLogVerbose(@"roster(%lu): %@", (unsigned long)[roster count], roster);
	}
	else
	{
		NSString *subscription = [item attributeStringValueForName:@"subscription"];
		
		if ([subscription isEqualToString:@"remove"])
		{
			XMPPUserMemoryStorage *user = [[[roster objectForKey:jid] retain] autorelease];
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
			XMPPUserMemoryStorage *user = [roster objectForKey:jid];
			if (user)
			{
				[user updateWithItem:item];
				
				XMPPLogVerbose(@"roster(%lu): %@", (unsigned long)[roster count], roster);
				
				[[self multicastDelegate] xmppRoster:self didUpdateUser:user];
				[[self multicastDelegate] xmppRosterDidChange:self];
			}
			else
			{
				XMPPUserMemoryStorage *newUser = (XMPPUserMemoryStorage *)[[self.userClass alloc] initWithItem:item];
				
				[roster setObject:newUser forKey:jid];
				[newUser autorelease];
				
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
	
	XMPPUserMemoryStorage *user = nil;
	XMPPResourceMemoryStorage *resource = nil;
	
	XMPPJID *jidKey = [[presence from] bareJID];
	
	user = [roster objectForKey:jidKey];
	if (user)
	{
		change = [user updateWithPresence:presence resourceClass:self.resourceClass andGetResource:&resource];
	}
	else
	{
		// Not a presence element for anyone in our roster.
		// Is it a presence element for our user (either our resource or another resource)?
		
		if ([[myJID bareJID] isEqualToJID:jidKey])
		{
			user = myUser;
			change = [myUser updateWithPresence:presence resourceClass:self.resourceClass andGetResource:&resource];
		}
	}
	
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
	XMPPUserMemoryStorage *rosterUser = [roster objectForKey:jidKey];
	
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
	XMPPUserMemoryStorage *rosterUser = [roster objectForKey:jidKey];
	
	if (rosterUser)
	{
		[rosterUser setPhoto:photo];
	}
}

- (void)clearAllResourcesForXMPPStream:(XMPPStream *)stream
{
	XMPPLogTrace();
	AssertParentQueue();
	
	for (XMPPUserMemoryStorage *user in [roster objectEnumerator])
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
	
	[myUser release];
	myUser = nil;
	
	[[self multicastDelegate] xmppRosterDidChange:self];
}

@end
