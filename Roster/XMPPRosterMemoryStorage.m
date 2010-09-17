#import "XMPP.h"
#import "XMPPRosterMemoryStorage.h"
#import "XMPPRosterPrivate.h"
#import "XMPPUserMemoryStorage.h"
#import "XMPPResourceMemoryStorage.h"



@interface XMPPRosterMemoryStorage (PrivateAPI)

- (BOOL)isRosterItem:(NSXMLElement *)item;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPRosterMemoryStorage

@synthesize parent;

- (MulticastDelegate <XMPPRosterMemoryStorageDelegate> *)multicastDelegate
{
	return (MulticastDelegate <XMPPRosterMemoryStorageDelegate> *)[parent multicastDelegate];
}

- (id)init
{
	if ((self = [super init]))
	{
		roster = [[NSMutableDictionary alloc] init];
	}
	return self;
}

- (void)dealloc
{
	[roster release];
	[myUser release];
	[super dealloc];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Roster Management
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (id <XMPPUser>)myUser
{
	return myUser;
}

- (id <XMPPResource>)myResource
{
	XMPPJID *myJID = parent.xmppStream.myJID;
	
	return [myUser resourceForJID:myJID];
}

- (id <XMPPUser>)userForJID:(XMPPJID *)jid
{
	id <XMPPUser> result = [roster objectForKey:[jid bareJID]];
	
	if(result)
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

- (id <XMPPResource>)resourceForJID:(XMPPJID *)jid
{
	id <XMPPUser> user = [self userForJID:jid];
	
	return [user resourceForJID:jid];
}

- (NSArray *)sortedUsersByName
{
	return [[roster allValues] sortedArrayUsingSelector:@selector(compareByName:)];
}

- (NSArray *)sortedUsersByAvailabilityName
{
	return [[roster allValues] sortedArrayUsingSelector:@selector(compareByAvailabilityName:)];
}

- (NSArray *)sortedAvailableUsersByName
{
	return [[self unsortedAvailableUsers] sortedArrayUsingSelector:@selector(compareByName:)];
}

- (NSArray *)sortedUnavailableUsersByName
{
	return [[self unsortedUnavailableUsers] sortedArrayUsingSelector:@selector(compareByName:)];
}

- (NSArray *)unsortedUsers
{
	return [roster allValues];
}

- (NSArray *)unsortedAvailableUsers
{
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

- (NSArray *)unsortedUnavailableUsers
{
	NSArray *allUsers = [roster allValues];
	
	NSMutableArray *result = [NSMutableArray arrayWithCapacity:[allUsers count]];
	
	for (id<XMPPUser> user in allUsers)
	{
		if (![user isOnline])
		{
			[result addObject:user];
		}
	}
	
	return result;
}

- (NSArray *)sortedResources:(BOOL)includeResourcesForMyUserExcludingMyself
{
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
#pragma mark Updates
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)beginRosterPopulation
{
	isRosterPopulation = YES;
	
	XMPPJID *myJID = parent.xmppStream.myJID;
	
	[myUser release];
	myUser = [[XMPPUserMemoryStorage alloc] initWithJID:myJID];
}

- (void)handleRosterItem:(NSXMLElement *)item
{
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

- (void)endRosterPopulation
{
	isRosterPopulation = NO;
	
	[[self multicastDelegate] xmppRosterDidChange:self];
}

- (void)handlePresence:(XMPPPresence *)presence
{
	XMPPJID *jidKey = [[presence from] bareJID];
	XMPPUserMemoryStorage *rosterUser = [roster objectForKey:jidKey];
	
	if(rosterUser)
	{
		[rosterUser updateWithPresence:presence];
		
		[[self multicastDelegate] xmppRosterDidChange:self];
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
			
			[[self multicastDelegate] xmppRosterDidChange:self];
		}
	}
}

- (void)clearAllResources
{
	NSEnumerator *enumerator = [roster objectEnumerator];
	XMPPUserMemoryStorage *user;
	
	while ((user = [enumerator nextObject]))
	{
		[user clearAllResources];
	}
	
	[[self multicastDelegate] xmppRosterDidChange:self];
}

- (void)clearAllUsersAndResources
{
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
