#import "XMPPRoster.h"
#import "XMPP.h"


enum XMPPRosterFlags
{
	kAutoRoster      = 1 << 0,  // If set, we automatically request roster after authentication
	kRequestedRoster = 1 << 1,  // If set, we have requested the roster
	kHasRoster       = 1 << 2,  // If set, we have received the roster
};

@interface XMPPRoster ()

@property(retain) NSMutableArray *earlyPresenceElements;
@property(assign) Byte flags;

- (void)xmppStream:(XMPPStream *)sender didReceivePresence:(XMPPPresence *)presence;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPRoster

@synthesize earlyPresenceElements;
@synthesize flags;
@synthesize xmppStream;
@synthesize xmppRosterStorage;
@dynamic    autoRoster;

/**
 * Private accessor for XMPPRosterStorage classes, which share the same delegate(s).
**/
- (MulticastDelegate *)multicastDelegate
{
	return multicastDelegate;
}

- (id)initWithStream:(XMPPStream *)stream rosterStorage:(id <XMPPRosterStorage>)storage
{
	if ((self = [super init]))
	{
		multicastDelegate = [[MulticastDelegate alloc] init];
		
		xmppStream = [stream retain];
		[xmppStream addDelegate:self];
		
		xmppRosterStorage = [storage retain];
        if ([xmppRosterStorage respondsToSelector:@selector(setParent:)]) {
            xmppRosterStorage.parent = self;
        }
		
		flags = 0;
		
		earlyPresenceElements = [[NSMutableArray alloc] initWithCapacity:2];
	}
	return self;
}

- (void)dealloc
{
	[multicastDelegate release];
	
	[xmppStream removeDelegate:self];
	[xmppStream release];
	
	[xmppRosterStorage release];
	
	[earlyPresenceElements release];
	
	[super dealloc];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Configuration
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)addDelegate:(id)delegate
{
	[multicastDelegate addDelegate:delegate];
}

- (void)removeDelegate:(id)delegate
{
	[multicastDelegate removeDelegate:delegate];
}

- (BOOL)autoRoster
{
	return (self.flags & kAutoRoster) ? YES : NO;
}

- (void)setAutoRoster:(BOOL)flag
{
	if(flag)
		self.flags |= kAutoRoster;
	else
		self.flags &= ~kAutoRoster;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Buddy Management
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)addBuddy:(XMPPJID *)jid withNickname:(NSString *)optionalName
{
	if(jid == nil) return;
	
	XMPPJID *myJID = xmppStream.myJID;
	
	if([[myJID bare] isEqualToString:[jid bare]])
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
	if(optionalName)
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
	if(jid == nil) return;
	
	XMPPJID *myJID = xmppStream.myJID;
	
	if([[myJID bare] isEqualToString:[jid bare]])
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
    [iq addAttributeWithName:@"id" stringValue:[xmppStream generateUUID]];
	[iq addChild:query];
	
	[xmppStream sendElement:iq];
}

- (void)setNickname:(NSString *)nickname forBuddy:(XMPPJID *)jid
{
	if(jid == nil) return;
	
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
	return (self.flags & kRequestedRoster) ? YES : NO;
}

- (void)setRequestedRoster:(BOOL)flag
{
	if(flag)
		self.flags |= kRequestedRoster;
	else
		self.flags &= ~kRequestedRoster;
}

- (BOOL)hasRoster
{
	return (self.flags & kHasRoster) ? YES : NO;
}

- (void)setHasRoster:(BOOL)flag
{
	if(flag)
		self.flags |= kHasRoster;
	else
		self.flags &= ~kHasRoster;
}

- (void)fetchRoster
{
	if ([self requestedRoster])
	{
		// We've already requested the roster from the server.
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
}


- (void)didReceivePresence:(XMPPPresence *)presence {
  [self xmppStream:xmppStream didReceivePresence:presence];
}


- (void)updateRosterWithQuery:(NSXMLElement *)query {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  [xmppRosterStorage beginRosterPopulationForXMPPStream:xmppStream];
  
  NSArray *items = [query elementsForName:@"item"];
  for (NSXMLElement *item in items)
  {
    // Filter out items for users who aren't actually in our roster.
    // That is, those users who have requested to be our buddy, but we haven't approved yet.
    
    [xmppRosterStorage handleRosterItem:item xmppStream:xmppStream];
  }
  
  [xmppRosterStorage endRosterPopulationForXMPPStream:xmppStream];
  
  [self setHasRoster:YES];
  
  // Which means we can process any premature presence elements we received
  for (XMPPPresence *presence in self.earlyPresenceElements)
  {
    // needs to happen on the main thread or context will get messed up
    [self performSelectorOnMainThread:@selector(didReceivePresence:)
                           withObject:presence
                        waitUntilDone:NO];
  }
  [self.earlyPresenceElements removeAllObjects];
  [pool release];
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Roster methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (id <XMPPUser>)myUser {
    return [self.xmppRosterStorage myUserForXMPPStream:xmppStream];
}
- (id <XMPPResource>)myResource {
    return [self.xmppRosterStorage myResourceForXMPPStream:xmppStream];
}

- (id <XMPPUser>)userForJID:(XMPPJID *)jid {
    return [self.xmppRosterStorage userForJID:jid xmppStream:xmppStream];
}

- (id <XMPPResource>)resourceForJID:(XMPPJID *)jid {
    return [self.xmppRosterStorage resourceForJID:jid xmppStream:xmppStream];
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStream Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender
{    
	if ([self autoRoster])
	{
		[self fetchRoster];
	}
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
    // We only want IQ for our stream
    if (sender != xmppStream) {
        return NO;
    }
    
	// Note: Some jabber servers send an iq element with an xmlns.
	// Because of the bug in Apple's NSXML (documented in our elementForName method),
	// it is important we specify the xmlns for the query.
	
	NSXMLElement *query = [iq elementForName:@"query" xmlns:@"jabber:iq:roster"];
	if (query)
	{
		if (![self hasRoster])
		{
      [self performSelectorInBackground:@selector(updateRosterWithQuery:) withObject:query];
		} else {
            NSArray *items = [query elementsForName:@"item"];
            for (NSXMLElement *item in items)
            {
                // Filter out items for users who aren't actually in our roster.
                // That is, those users who have requested to be our buddy, but we haven't approved yet.
                
                [xmppRosterStorage handleRosterItem:item xmppStream:sender];
            }            
        }
        
        // return result
        if ([iq requiresResponse]) {
            XMPPIQ *iqResponse = [XMPPIQ iqWithType:@"result" to:[iq from] elementID:[iq elementID]];
            NSXMLElement *resultQuery = [[query copy] autorelease];
            [iqResponse addChild:resultQuery];
            
            [sender sendElement:iqResponse];
        }
        return YES;
    }
	return NO;
}
 
- (void)xmppStream:(XMPPStream *)sender didReceivePresence:(XMPPPresence *)presence
{
    // We only want Presence for our stream
    if (sender != xmppStream) {
        return;
    }
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
			[self.earlyPresenceElements addObject:presence];
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
		id <XMPPUser> user = [xmppRosterStorage userForJID:[presence from] xmppStream:sender];
		
		if(user && [self autoRoster])
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
		[xmppRosterStorage handlePresence:presence xmppStream:sender];
	}
}

- (void)xmppStream:(XMPPStream *)sender didSendPresence:(XMPPPresence *)presence
{
    // We only want Presence for our stream
    if (sender != xmppStream) {
        return;
    }
    
	if ([[presence type] isEqualToString:@"unavailable"])
	{
		// We don't receive presence notifications when we're offline.
		// So we need to remove all resources from our roster when we're offline.
		// When we become available again, we'll automatically receive the
		// presence from every available user in our roster.
		// 
		// We will receive general roster updates as long as we're still connected though.
		// So there's no need to refetch the roster.
		
		[xmppRosterStorage clearAllResourcesForXMPPStream:sender];
		
		[self.earlyPresenceElements removeAllObjects];
	}
}

// try using xmppStreamWillConnect, so we can keep user info when we go offline temporarily
//- (void)xmppStreamWillConnect:(XMPPStream *)sender
- (void)xmppStreamDidDisconnect:(XMPPStream *)sender
{
    if (sender != xmppStream) {
        return;
    }
	[xmppRosterStorage clearAllUsersAndResourcesForXMPPStream:sender];
	
	[self setRequestedRoster:NO];
	[self setHasRoster:NO];
	
	[self.earlyPresenceElements removeAllObjects];
}

@end
