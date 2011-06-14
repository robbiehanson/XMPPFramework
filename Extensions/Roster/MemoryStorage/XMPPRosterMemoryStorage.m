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

@interface XMPPRosterMemoryStorage (PrivateAPI)

- (BOOL)isRosterItem:(NSXMLElement *)item;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPRosterMemoryStorage

@synthesize parent;

- (GCDMulticastDelegate <XMPPRosterMemoryStorageDelegate> *)multicastDelegate
{
	return (GCDMulticastDelegate <XMPPRosterMemoryStorageDelegate> *)[parent multicastDelegate];
}

- (id)init
{
	if ((self = [super init]))
	{
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
		parent = aParent; // Parents retain their children, children do NOT retain their parent
		
		parentQueue = queue;
		dispatch_retain(parentQueue);
		
		return YES;
	}
	
	return NO;
}

- (void)dealloc
{
	if (parentQueue)
		dispatch_release(parentQueue);
	
	[roster release];
	[myUser release];
	[super dealloc];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Internal API
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (id <XMPPUser>)_userForJID:(XMPPJID *)jid
{
	// Private method: Only invoked on the parentQueue.
	
	XMPPUserMemoryStorage *result = [roster objectForKey:[jid bareJID]];
	
	if (result)
	{
		return result;
	}
	
	XMPPJID *myJID = parent.xmppStream.myJID;
	
	XMPPJID *myBareJID = [myJID bareJID];
	XMPPJID *bareJID = [jid bareJID];
	
	if ([bareJID isEqual:myBareJID])
	{
		return myUser;
	}
	
	return nil;
}

- (id <XMPPResource>)_resourceForJID:(XMPPJID *)jid
{
	// Private method: Only invoked on the parentQueue.
	
	XMPPUserMemoryStorage *user = (XMPPUserMemoryStorage *)[self _userForJID:jid];
	return [user resourceForJID:jid];
}

- (NSArray *)_unsortedUsers
{
	// Private method: Only invoked on the parentQueue.
	
	return [roster allValues];
}

- (NSArray *)_unsortedAvailableUsers
{
	// Private method: Only invoked on the parentQueue.
	
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
	// Private method: Only invoked on the parentQueue.
	
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
	// Private method: Only invoked on the parentQueue.
	
	return [[roster allValues] sortedArrayUsingSelector:@selector(compareByName:)];
}

- (NSArray *)_sortedUsersByAvailabilityName
{
	// Private method: Only invoked on the parentQueue.
	
	return [[roster allValues] sortedArrayUsingSelector:@selector(compareByAvailabilityName:)];
}

- (NSArray *)_sortedAvailableUsersByName
{
	// Private method: Only invoked on the parentQueue.
	
	return [[self _unsortedAvailableUsers] sortedArrayUsingSelector:@selector(compareByName:)];
}

- (NSArray *)_sortedUnavailableUsersByName
{
	// Private method: Only invoked on the parentQueue.
	
	return [[self _unsortedUnavailableUsers] sortedArrayUsingSelector:@selector(compareByName:)];
}

- (NSArray *)_sortedResources:(BOOL)includeResourcesForMyUserExcludingMyself
{
	// Private method: Only invoked on the parentQueue.
	
	// Add all the resouces from all the available users in the roster
	// 
	// Remember: There may be multiple resources per user
	
	NSArray *availableUsers = [self unsortedAvailableUsers];
	
	NSMutableArray *result = [NSMutableArray arrayWithCapacity:[availableUsers count]];
	
	for (id<XMPPUser> user in availableUsers)
	{
		[result addObjectsFromArray:[user unsortedResources]];
	}
	
	if (includeResourcesForMyUserExcludingMyself)
	{
		// Now add all the available resources from our own user account (excluding ourselves)
		
		XMPPJID *myJID = parent.xmppStream.myJID;
		NSArray *myResources = [myUser unsortedResources];
		
		for (id<XMPPResource> resource in myResources)
		{
			if (![myJID isEqual:[resource jid]])
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
	// This is a public method.
	// It may be invoked on any thread/queue.
	
	if (parentQueue == NULL) return nil;
	
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
	// This is a public method.
	// It may be invoked on any thread/queue.
	
	if (parentQueue == NULL) return nil;
	
	XMPPJID *myJID = parent.xmppStream.myJID;
	
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
	// This is a public method.
	// It may be invoked on any thread/queue.
	
	if (parentQueue == NULL) return nil;
	
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
	// This is a public method.
	// It may be invoked on any thread/queue.
	
	if (parentQueue == NULL) return nil;
	
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
	// This is a public method.
	// It may be invoked on any thread/queue.
	
	if (parentQueue == NULL) return nil;
	
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
	// This is a public method.
	// It may be invoked on any thread/queue.
	
	if (parentQueue == NULL) return nil;
	
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
	// This is a public method.
	// It may be invoked on any thread/queue.
	
	if (parentQueue == NULL) return nil;
	
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
	// This is a public method.
	// It may be invoked on any thread/queue.
	
	if (parentQueue == NULL) return nil;
	
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
	// This is a public method.
	// It may be invoked on any thread/queue.
	
	if (parentQueue == NULL) return nil;
	
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
	// This is a public method.
	// It may be invoked on any thread/queue.
	
	if (parentQueue == NULL) return nil;
	
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
	// This is a public method.
	// It may be invoked on any thread/queue.
	
	if (parentQueue == NULL) return nil;
	
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
	// This is a public method.
	// It may be invoked on any thread/queue.
	
	if (parentQueue == NULL) return nil;
	
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

- (id <XMPPUser>)myUserForXMPPStream:(XMPPStream *)stream
{
	return [self myUser];
}

- (id <XMPPResource>)myResourceForXMPPStream:(XMPPStream *)stream
{
	return [self myResource];
}

- (id <XMPPUser>)userForJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream
{
	return [self userForJID:jid];
}

- (id <XMPPResource>)resourceForJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream
{
	return [self resourceForJID:jid];
}

- (void)beginRosterPopulationForXMPPStream:(XMPPStream *)stream
{
	XMPPLogTrace();
	
	isRosterPopulation = YES;
	
	XMPPJID *myJID = parent.xmppStream.myJID;
	
	[myUser release];
	myUser = [[XMPPUserMemoryStorage alloc] initWithJID:myJID];
}

- (void)endRosterPopulationForXMPPStream:(XMPPStream *)stream
{
	XMPPLogTrace();
	
	isRosterPopulation = NO;
	
	[[self multicastDelegate] xmppRosterDidChange:self];
}

- (void)handleRosterItem:(NSXMLElement *)item xmppStream:(XMPPStream *)stream
{
	XMPPLogTrace();
	
	if ([self isRosterItem:item])
	{
		NSString *jidStr = [item attributeStringValueForName:@"jid"];
		XMPPJID *jid = [[XMPPJID jidWithString:jidStr] bareJID];
		
		NSString *subscription = [item attributeStringValueForName:@"subscription"];
		
		if ([subscription isEqualToString:@"remove"])
		{
			[roster removeObjectForKey:jid];
		}
		else
		{
			XMPPUserMemoryStorage *user = [roster objectForKey:jid];
			if (user)
			{
				[user updateWithItem:item];
			}
			else
			{
				XMPPUserMemoryStorage *newUser = [[XMPPUserMemoryStorage alloc] initWithItem:item];
				
				[roster setObject:newUser forKey:jid];
				[newUser release];
			}
		}
		
		if (!isRosterPopulation)
		{
			[[self multicastDelegate] xmppRosterDidChange:self];
		}
	}
}

- (void)handlePresence:(XMPPPresence *)presence xmppStream:(XMPPStream *)stream
{
	XMPPLogTrace();
	
	XMPPJID *jidKey = [[presence from] bareJID];
	XMPPUserMemoryStorage *rosterUser = [roster objectForKey:jidKey];
	
	if (rosterUser)
	{
		[rosterUser updateWithPresence:presence];
		
		if (!isRosterPopulation)
		{
			[[self multicastDelegate] xmppRosterDidChange:self];
		}
	}
	else
	{
		// Not a presence element for anyone in our roster.
		// Is it a presence element for our user (either our resource or another resource)?
		
		XMPPJID *myJID = parent.xmppStream.myJID;
		XMPPJID *myBareJID = [myJID bareJID];
		
		if([myBareJID isEqual:jidKey])
		{
			[myUser updateWithPresence:presence];
			
			if (!isRosterPopulation)
			{
				[[self multicastDelegate] xmppRosterDidChange:self];
			}
		}
	}
}

- (void)clearAllResourcesForXMPPStream:(XMPPStream *)stream
{
	XMPPLogTrace();
	
	NSEnumerator *enumerator = [roster objectEnumerator];
	XMPPUserMemoryStorage *user;
	
	while ((user = [enumerator nextObject]))
	{
		[user clearAllResources];
	}
	
	[[self multicastDelegate] xmppRosterDidChange:self];
}

- (void)clearAllUsersAndResourcesForXMPPStream:(XMPPStream *)stream
{
	XMPPLogTrace();
	
	[roster removeAllObjects];
	
	[myUser release];
	myUser = nil;
	
	[[self multicastDelegate] xmppRosterDidChange:self];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * For some bizarre reason (in my opinion), when you request your roster,
 * the server will return JID's NOT in your roster.
 * These are the JID's of users who have requested to be alerted to our presence.
 * After we sign in, we'll again be notified, via the normal presence request objects.
 * It's redundant, and annoying, and just plain incorrect to include these JID's when we request our personal roster.
 * So now, we have to go to the extra effort to filter out these JID's, which is exactly what this method does.
**/
- (BOOL)isRosterItem:(NSXMLElement *)item
{
	NSString *subscription = [item attributeStringValueForName:@"subscription"];
	if ([subscription isEqualToString:@"none"])
	{
		NSString *ask = [item attributeStringValueForName:@"ask"];
		if ([ask isEqualToString:@"subscribe"])
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

@end
