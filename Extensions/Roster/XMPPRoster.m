#import "XMPPRoster.h"
#import "XMPP.h"
#import "XMPPLogging.h"

// Log levels: off, error, warn, info, verbose
// Log flags: trace
#if DEBUG
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN; // | XMPP_LOG_FLAG_TRACE;
#else
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

enum XMPPRosterFlags
{
	kAutoRoster      = 1 << 0,  // If set, we automatically request roster after authentication
	kRequestedRoster = 1 << 1,  // If set, we have requested the roster
	kHasRoster       = 1 << 2,  // If set, we have received the roster
};

@interface XMPPRoster (PrivateAPI)

- (void)xmppStream:(XMPPStream *)sender didReceivePresence:(XMPPPresence *)presence;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPRoster

@dynamic xmppRosterStorage;
@dynamic autoRoster;

- (id)init
{
	return [self initWithRosterStorage:nil dispatchQueue:NULL];
}

- (id)initWithDispatchQueue:(dispatch_queue_t)queue
{
	return [self initWithRosterStorage:nil dispatchQueue:queue];
}

- (id)initWithRosterStorage:(id <XMPPRosterStorage>)storage
{
	return [self initWithRosterStorage:storage dispatchQueue:NULL];
}

- (id)initWithRosterStorage:(id <XMPPRosterStorage>)storage dispatchQueue:(dispatch_queue_t)queue
{
	NSParameterAssert(storage != nil);
	
	if ((self = [super initWithDispatchQueue:queue]))
	{
		if ([storage configureWithParent:self queue:moduleQueue])
		{
			xmppRosterStorage = [storage retain];
		}
		else
		{
			XMPPLogError(@"%@: %@ - Unable to configure storage!", THIS_FILE, THIS_METHOD);
		}
		
		flags = 0;
		earlyPresenceElements = [[NSMutableArray alloc] initWithCapacity:2];
	}
	return self;
}

- (BOOL)activate:(XMPPStream *)aXmppStream
{
	XMPPLogTrace();
	
	if ([super activate:aXmppStream])
	{
		XMPPLogVerbose(@"%@: Activated", THIS_FILE);
		
		// Custom code goes here (if needed)
		
		return YES;
	}
	
	return NO;
}

- (void)deactivate
{
	XMPPLogTrace();
	
	// Custom code goes here (if needed)
	
	[super deactivate];
}

- (void)dealloc
{
	[xmppRosterStorage release];
	[earlyPresenceElements release];
	[super dealloc];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Internal
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method is used by XMPPRosterStorage classes.
**/
- (GCDMulticastDelegate *)multicastDelegate
{
	return multicastDelegate;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Configuration
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSString *)moduleName
{
	return @"XMPPRoster";
}

- (id <XMPPRosterStorage>)xmppRosterStorage
{
	// Note: The xmppRosterStorage variable is read-only (set in the init method)
	
	return [[xmppRosterStorage retain] autorelease];
}

- (BOOL)autoRoster
{
	__block BOOL result;
	
	dispatch_block_t block = ^{
		result = (flags & kAutoRoster) ? YES : NO;
	};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_sync(moduleQueue, block);
	
	return result;
}

- (void)setAutoRoster:(BOOL)flag
{
	dispatch_block_t block = ^{
		
		if (flag)
			flags |= kAutoRoster;
		else
			flags &= ~kAutoRoster;
	};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_async(moduleQueue, block);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Buddy Management
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)addBuddy:(XMPPJID *)jid withNickname:(NSString *)optionalName
{
	// This is a public method.
	// It may be invoked on any thread/queue.
	
	if (jid == nil) return;
	
	XMPPJID *myJID = xmppStream.myJID;
	
	if ([[myJID bare] isEqualToString:[jid bare]])
	{
		// No, you don't need to add yourself
		return;
	}
	
	// Add the buddy to our roster
	// 
	// <iq type="set">
	//   <query xmlns="jabber:iq:roster">
	//     <item jid="bareJID" name="optionalName"/>
	//   </query>
	// </iq>
	
	NSXMLElement *item = [NSXMLElement elementWithName:@"item"];
	[item addAttributeWithName:@"jid" stringValue:[jid bare]];
	
	if (optionalName)
	{
		[item addAttributeWithName:@"name" stringValue:optionalName];
	}
	
	NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"jabber:iq:roster"];
	[query addChild:item];
	
	NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
	[iq addAttributeWithName:@"type" stringValue:@"set"];
	[iq addChild:query];
	
	[xmppStream sendElement:iq];
	
	// Subscribe to the buddy's presence
	// 
	// <presence to="bareJID" type="subscribe"/>
	
	NSXMLElement *presence = [NSXMLElement elementWithName:@"presence"];
	[presence addAttributeWithName:@"to" stringValue:[jid bare]];
	[presence addAttributeWithName:@"type" stringValue:@"subscribe"];
	
	[xmppStream sendElement:presence];
}

- (void)removeBuddy:(XMPPJID *)jid
{
	// This is a public method.
	// It may be invoked on any thread/queue.
	
	if (jid == nil) return;
	
	XMPPJID *myJID = xmppStream.myJID;
	
	if ([[myJID bare] isEqualToString:[jid bare]])
	{
		// No, you shouldn't remove yourself
		return;
	}
	
	// Remove the buddy from our roster
	// Unsubscribe from presence
	// And revoke contact's subscription to our presence
	// ...all in one step
	
	// <iq type="set">
	//   <query xmlns="jabber:iq:roster">
	//     <item jid="bareJID" subscription="remove"/>
	//   </query>
	// </iq>
	
	NSXMLElement *item = [NSXMLElement elementWithName:@"item"];
	[item addAttributeWithName:@"jid" stringValue:[jid bare]];
	[item addAttributeWithName:@"subscription" stringValue:@"remove"];
	
	NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"jabber:iq:roster"];
	[query addChild:item];
	
	NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
	[iq addAttributeWithName:@"type" stringValue:@"set"];
	[iq addChild:query];
	
	[xmppStream sendElement:iq];
}

- (void)setNickname:(NSString *)nickname forBuddy:(XMPPJID *)jid
{
	// This is a public method.
	// It may be invoked on any thread/queue.
	
	if (jid == nil) return;
	
	// <iq type="set">
	//   <query xmlns="jabber:iq:roster">
	//     <item jid="bareJID" name="nickname"/>
	//   </query>
	// </iq>
	
	NSXMLElement *item = [NSXMLElement elementWithName:@"item"];
	[item addAttributeWithName:@"jid" stringValue:[jid bare]];
	[item addAttributeWithName:@"name" stringValue:nickname];
	
	NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"jabber:iq:roster"];
	[query addChild:item];
	
	NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
	[iq addAttributeWithName:@"type" stringValue:@"set"];
	[iq addChild:query];
	
	[xmppStream sendElement:iq];
}

- (void)acceptBuddyRequest:(XMPPJID *)jid
{
	// This is a public method.
	// It may be invoked on any thread/queue.
	
	// Send presence response
	// 
	// <presence to="bareJID" type="subscribed"/>
	
	NSXMLElement *response = [NSXMLElement elementWithName:@"presence"];
	[response addAttributeWithName:@"to" stringValue:[jid bare]];
	[response addAttributeWithName:@"type" stringValue:@"subscribed"];
	
	[xmppStream sendElement:response];
	
	// Add user to our roster
	
	[self addBuddy:jid withNickname:nil];
}

- (void)rejectBuddyRequest:(XMPPJID *)jid
{
	// This is a public method.
	// It may be invoked on any thread/queue.
	
	// Send presence response
	// 
	// <presence to="bareJID" type="unsubscribed"/>
	
	NSXMLElement *response = [NSXMLElement elementWithName:@"presence"];
	[response addAttributeWithName:@"to" stringValue:[jid bare]];
	[response addAttributeWithName:@"type" stringValue:@"unsubscribed"];
	
	[xmppStream sendElement:response];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)requestedRoster
{
	NSAssert(dispatch_get_current_queue() == moduleQueue, @"Invoked on incorrect queue");
	
	return (flags & kRequestedRoster) ? YES : NO;
}

- (void)setRequestedRoster:(BOOL)flag
{
	NSAssert(dispatch_get_current_queue() == moduleQueue, @"Invoked on incorrect queue");
	
	if (flag)
		flags |= kRequestedRoster;
	else
		flags &= ~kRequestedRoster;
}

- (BOOL)hasRoster
{
	NSAssert(dispatch_get_current_queue() == moduleQueue, @"Invoked on incorrect queue");
	
	return (flags & kHasRoster) ? YES : NO;
}

- (void)setHasRoster:(BOOL)flag
{
	NSAssert(dispatch_get_current_queue() == moduleQueue, @"Invoked on incorrect queue");
	
	if (flag)
		flags |= kHasRoster;
	else
		flags &= ~kHasRoster;
}

- (void)fetchRoster
{
	// This is a public method.
	// It may be invoked on any thread/queue.
	
	dispatch_block_t block = ^{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		if ([self requestedRoster])
		{
			// We've already requested the roster from the server.
			[pool drain];
			return;
		}
		
		// <iq type="get">
		//   <query xmlns="jabber:iq:roster"/>
		// </iq>
		
		NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"jabber:iq:roster"];
		
		NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
		[iq addAttributeWithName:@"type" stringValue:@"get"];
		[iq addChild:query];
		
		[xmppStream sendElement:iq];
		
		[self setRequestedRoster:YES];
		
		[pool drain];
	};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_async(moduleQueue, block);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Roster methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (id <XMPPUser>)myUser {
    return [xmppRosterStorage myUserForXMPPStream:xmppStream];
}
- (id <XMPPResource>)myResource {
    return [xmppRosterStorage myResourceForXMPPStream:xmppStream];
}

- (id <XMPPUser>)userForJID:(XMPPJID *)jid {
    return [xmppRosterStorage userForJID:jid xmppStream:xmppStream];
}

- (id <XMPPResource>)resourceForJID:(XMPPJID *)jid {
    return [xmppRosterStorage resourceForJID:jid xmppStream:xmppStream];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStream Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender
{
	// This method is invoked on the moduleQueue.
	
	XMPPLogTrace();
	
	if ([self autoRoster])
	{
		[self fetchRoster];
	}
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
	// This method is invoked on the moduleQueue.
	
	XMPPLogTrace();
	
	// Note: Some jabber servers send an iq element with an xmlns.
	// Because of the bug in Apple's NSXML (documented in our elementForName method),
	// it is important we specify the xmlns for the query.
	
	NSXMLElement *query = [iq elementForName:@"query" xmlns:@"jabber:iq:roster"];
	if (query)
	{
		if (![self hasRoster])
		{
			[xmppRosterStorage beginRosterPopulationForXMPPStream:xmppStream];
		}
		
		NSArray *items = [query elementsForName:@"item"];
		for (NSXMLElement *item in items)
		{
			// Filter out items for users who aren't actually in our roster.
			// That is, those users who have requested to be our buddy, but we haven't approved yet.
			
			[xmppRosterStorage handleRosterItem:item xmppStream:xmppStream];
		}
		
		if (![self hasRoster])
		{
			// We should have our roster now
			
			[self setHasRoster:YES];
			
			// Which means we can process any premature presence elements we received.
			// 
			// Note: We do this before invoking endRosterPopulation to enable optimizations
			// concerning the possible presence storm.
			
			for (XMPPPresence *presence in earlyPresenceElements)
			{
				[self xmppStream:xmppStream didReceivePresence:presence];
			}
			[earlyPresenceElements removeAllObjects];
			
			// And finally, notify roster storage that the roster population is complete
			[xmppRosterStorage endRosterPopulationForXMPPStream:xmppStream];
		}
		
		return YES;
	}
	
	return NO;
}

- (void)xmppStream:(XMPPStream *)sender didReceivePresence:(XMPPPresence *)presence
{
	// This method is invoked on the moduleQueue.
	
	XMPPLogTrace();
	
	if (![self hasRoster])
	{
		// We received a presence notification,
		// but we don't have a roster to apply it to yet.
		// 
		// This is possible if we send our presence before we've received our roster.
		// It's even possible if we send our presence after we've requested our roster.
		// There is no guarantee the server will process our requests serially,
		// and the server may start sending presence elements before it sends our roster.
		// 
		// However, if we've requested the roster,
		// then it shouldn't be too long before we receive it.
		// So we should be able to simply queue the presence elements for later processing.
		
		if ([self requestedRoster])
		{
			// We store the presence element until we get our roster.
			[earlyPresenceElements addObject:presence];
		}
		else
		{
			// The user has not requested the roster.
			// This is a rogue presence element, or the user is simply not using our roster management.
		}
		
		return;
	}
	
	if ([[presence type] isEqualToString:@"subscribe"])
	{
		id <XMPPUser> user = [xmppRosterStorage userForJID:[presence from] xmppStream:xmppStream];
		
		if (user && [self autoRoster])
		{
			// Presence subscription request from someone who's already in our roster.
			// Automatically approve.
			// 
			// <presence to="bareJID" type="subscribed"/>
			
			NSXMLElement *response = [NSXMLElement elementWithName:@"presence"];
			[response addAttributeWithName:@"to" stringValue:[[presence from] bare]];
			[response addAttributeWithName:@"type" stringValue:@"subscribed"];
			
			[xmppStream sendElement:response];
		}
		else
		{
			// Presence subscription request from someone who's NOT in our roster
			
			[multicastDelegate xmppRoster:self didReceiveBuddyRequest:presence];
		}
	}
	else
	{
		[xmppRosterStorage handlePresence:presence xmppStream:xmppStream];
	}
}

- (void)xmppStream:(XMPPStream *)sender didSendPresence:(XMPPPresence *)presence
{
	// This method is invoked on the moduleQueue.
	
	XMPPLogTrace();
	
	if ([[presence type] isEqualToString:@"unavailable"])
	{
		// We don't receive presence notifications when we're offline.
		// So we need to remove all resources from our roster when we're offline.
		// When we become available again, we'll automatically receive the
		// presence from every available user in our roster.
		// 
		// We will receive general roster updates as long as we're still connected though.
		// So there's no need to refetch the roster.
		
		[xmppRosterStorage clearAllResourcesForXMPPStream:xmppStream];
		
		[earlyPresenceElements removeAllObjects];
	}
}

- (void)xmppStreamDidDisconnect:(XMPPStream *)sender withError:(NSError *)error
{
	// This method is invoked on the moduleQueue.
	
	XMPPLogTrace();
	
	[xmppRosterStorage clearAllUsersAndResourcesForXMPPStream:xmppStream];
	
	[self setRequestedRoster:NO];
	[self setHasRoster:NO];
	
	[earlyPresenceElements removeAllObjects];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPvCardAvatarDelegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#if TARGET_OS_IPHONE
- (void)xmppvCardAvatarModule:(XMPPvCardAvatarModule *)vCardTempModule 
              didReceivePhoto:(UIImage *)photo 
                       forJID:(XMPPJID *)jid
#else
- (void)xmppvCardAvatarModule:(XMPPvCardAvatarModule *)vCardTempModule 
              didReceivePhoto:(NSImage *)photo 
                       forJID:(XMPPJID *)jid
#endif
{
	id <XMPPUser> user = [self userForJID:jid];

	if (user != nil) {
		user.photo = photo;
	}
}

@end
