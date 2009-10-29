#import "XMPPClient.h"
#import "XMPPJID.h"
#import "XMPPUser.h"
#import "XMPPResource.h"
#import "XMPPIQ.h"
#import "XMPPMessage.h"
#import "XMPPPresence.h"
#import "NSXMLElementAdditions.h"

#if !TARGET_OS_IPHONE
#import "SCNotificationManager.h"
#endif

enum XMPPClientFlags
{
	kUsesOldStyleSSL      = 1 << 0,  // If set, TLS is established prior to any communication (no StartTLS)
	kAutoLogin            = 1 << 1,  // If set, client automatically attempts login after connection is established
	kAllowsPlaintextAuth  = 1 << 2,  // If set, client allows plaintext authentication
	kAutoRoster           = 1 << 3,  // If set, client automatically request roster after authentication
	kAutoPresence         = 1 << 4,  // If set, client automatically becaomes available after authentication
	kAutoReconnect        = 1 << 5,  // If set, client automatically attempts to reconnect after a disconnection
	kShouldReconnect      = 1 << 6,  // If set, disconnection was accidental, and autoReconnect may be used
	kRequestedRoster      = 1 << 7,  // If set, client has requested the roster
	kHasRoster            = 1 << 8,  // If set, client has received the roster
};

@interface XMPPClient (PrivateAPI)

- (BOOL)requestedRoster;
- (void)setRequestedRoster:(BOOL)flag;

- (BOOL)hasRoster;
- (void)setHasRoster:(BOOL)flag;

- (void)clearRoster;

- (void)onConnecting;
- (void)onDidConnect;
- (void)onDidDisconnect;
- (void)onDidRegister;
- (void)onDidNotRegister:(NSXMLElement *)error;
- (void)onDidAuthenticate;
- (void)onDidNotAuthenticate:(NSXMLElement *)error;
- (void)onDidUpdateRoster;
- (void)onDidReceiveBuddyRequest:(XMPPJID *)jid;
- (void)onDidReceiveIQ:(XMPPIQ *)iq;
- (void)onDidReceiveMessage:(XMPPMessage *)message;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPClient

- (id)init
{
	if((self = [super init]))
	{
		multicastDelegate = [[MulticastDelegate alloc] init];
		
		priority = 1;
		flags = 0;
		
		[self setAutoLogin:YES];
		[self setAllowsPlaintextAuth:YES];
		[self setAutoPresence:YES];
		[self setAutoRoster:YES];
		[self setAutoReconnect:YES];
		
		xmppStream = [[XMPPStream alloc] initWithDelegate:self];
		
		roster = [[NSMutableDictionary alloc] initWithCapacity:10];
		
		earlyPresenceElements = [[NSMutableArray alloc] initWithCapacity:2];
		
#if !TARGET_OS_IPHONE		
		scNotificationManager = [[SCNotificationManager alloc] init];
		
		// Register for network notifications from system configuration
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(networkStatusDidChange:) 
													 name:@"State:/Network/Global/IPv4" 
												   object:scNotificationManager];
#endif
	}
	return self;
}

- (void)dealloc
{
	[multicastDelegate release];
	
	[domain release];
	[myJID release];
	[password release];
	
	[xmppStream setDelegate:nil];
	[xmppStream disconnect];
	[xmppStream release];
	[streamError release];
	
	[roster release];
	[myUser release];
	
	[earlyPresenceElements release];

#if !TARGET_OS_IPHONE	
	[scNotificationManager release];
#endif
	
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

- (NSString *)domain
{
	return domain;
}
- (void)setDomain:(NSString *)newDomain
{
	if(![domain isEqual:newDomain])
	{
		[domain release];
		domain = [newDomain copy];
	}
}

- (UInt16)port
{
	return port;
}
- (void)setPort:(UInt16)newPort
{
	port = newPort;
}

- (BOOL)usesOldStyleSSL
{
	return (BOOL)(flags & kUsesOldStyleSSL);
}
- (void)setUsesOldStyleSSL:(BOOL)flag
{
	if(flag)
		flags |= kUsesOldStyleSSL;
	else
		flags &= ~kUsesOldStyleSSL;
}

- (XMPPJID *)myJID
{
	return myJID;
}
- (void)setMyJID:(XMPPJID *)jid
{
	if(![myJID isEqual:jid])
	{
		[myJID release];
		myJID = [jid retain];
	}
}

- (NSString *)password
{
	return password;
}
- (void)setPassword:(NSString *)newPassword
{
	if(![password isEqual:newPassword])
	{
		[password release];
		password = [newPassword copy];
	}
}

- (int)priority
{
	return priority;
}
- (void)setPriority:(int)newPriority
{
	priority = newPriority;
}

- (BOOL)allowsSelfSignedCertificates
{
	return [xmppStream allowsSelfSignedCertificates];
}
- (void)setAllowsSelfSignedCertificates:(BOOL)flag
{
	[xmppStream setAllowsSelfSignedCertificates:flag];
}

- (BOOL)allowsSSLHostNameMismatch
{
	return [xmppStream allowsSSLHostNameMismatch];
}
- (void)setAllowsSSLHostNameMismatch:(BOOL)flag
{
	[xmppStream setAllowsSSLHostNameMismatch:flag];
}

- (BOOL)isDisconnected
{
	return [xmppStream isDisconnected];
}

- (BOOL)isConnected
{
	return [xmppStream isConnected];
}

- (BOOL)isSecure
{
	return [xmppStream isSecure];
}

- (BOOL)autoLogin
{
	return (BOOL)(flags & kAutoLogin);
}
- (void)setAutoLogin:(BOOL)flag
{
	if(flag)
		flags |= kAutoLogin;
	else
		flags &= ~kAutoLogin;
}

- (BOOL)autoRoster
{
	return (BOOL)(flags & kAutoRoster);
}
- (void)setAutoRoster:(BOOL)flag
{
	if(flag)
		flags |= kAutoRoster;
	else
		flags &= ~kAutoRoster;
}

- (BOOL)autoPresence
{
	return (BOOL)(flags & kAutoPresence);
}
- (void)setAutoPresence:(BOOL)flag
{
	if(flag)
		flags |= kAutoPresence;
	else
		flags &= ~kAutoPresence;
}

- (BOOL)autoReconnect
{
	return (BOOL)(flags & kAutoReconnect);
}
- (void)setAutoReconnect:(BOOL)flag
{
	if(flag)
		flags |= kAutoReconnect;
	else
		flags &= ~kAutoReconnect;
}

- (BOOL)shouldReconnect
{
	return (BOOL)(flags & kShouldReconnect);
}
- (void)setShouldReconnect:(BOOL)flag
{
	if(flag)
		flags |= kShouldReconnect;
	else
		flags &= ~kShouldReconnect;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Connecting, Registering and Authenticating
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)connect
{
	[self onConnecting];
	
	if([self usesOldStyleSSL])
		[xmppStream connectToSecureHost:domain onPort:port withVirtualHost:[myJID domain]];
	else
		[xmppStream connectToHost:domain onPort:port withVirtualHost:[myJID domain]];
}

- (void)disconnect
{
	// Turn off the shouldReconnect flag.
	// This flag will tell us that we should not automatically attempt to reconnect when the connection closes.
	[self setShouldReconnect:NO];
	
	[xmppStream disconnect];
}

- (BOOL)supportsInBandRegistration
{
	return [xmppStream supportsInBandRegistration];
}

- (void)registerUser
{
	[xmppStream registerUser:[myJID user] withPassword:password];
}

- (BOOL)supportsPlainAuthentication
{
	return [xmppStream supportsPlainAuthentication];
}
- (BOOL)supportsDigestMD5Authentication
{
	return [xmppStream supportsDigestMD5Authentication];
}

- (BOOL)allowsPlaintextAuth
{
	return (BOOL)(flags & kAllowsPlaintextAuth);
}
- (void)setAllowsPlaintextAuth:(BOOL)flag
{
	if(flag)
		flags |= kAllowsPlaintextAuth;
	else
		flags &= ~kAllowsPlaintextAuth;
}

- (void)authenticateUser
{
	BOOL secureAuth = NO;
	
	if([xmppStream supportsDigestMD5Authentication])
	{
		secureAuth = YES;
	}
	else if([xmppStream supportsPlainAuthentication])
	{
		secureAuth = [xmppStream isSecure];
	}
	else if([xmppStream supportsDeprecatedDigestAuthentication])
	{
		secureAuth = YES;
	}
	else
	{
		secureAuth = [xmppStream isSecure];
	}
	
	if(secureAuth || [self allowsPlaintextAuth])
	{
		[xmppStream authenticateUser:[myJID user] withPassword:password resource:[myJID resource]];
	}
}

- (BOOL)isAuthenticated
{
	return [xmppStream isAuthenticated];
}

- (NSError *)streamError
{
    return streamError;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Presence Managment
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)goOnline
{
	NSString *priorityStr = [NSString stringWithFormat:@"%i", priority];
	
	NSXMLElement *presence = [NSXMLElement elementWithName:@"presence"];
	[presence addChild:[NSXMLElement elementWithName:@"priority" stringValue:priorityStr]];
	
	[xmppStream sendElement:presence];
}

- (void)goOffline
{
	// Send offline presence element
	NSXMLElement *presence = [NSXMLElement elementWithName:@"presence"];
	[presence addAttributeWithName:@"type" stringValue:@"unavailable"];
	
	[xmppStream sendElement:presence];
	
	// Remove all users from our roster when we're offline.
	// We don't receive presence notifications when we're offline.
	
	BOOL didUpdateRoster = ([roster count] > 0);
	
	[self clearRoster];
	
	if(didUpdateRoster)
	{
		[self onDidUpdateRoster];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Roster Managment
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)requestedRoster
{
	return (BOOL)(flags & kRequestedRoster);
}
- (void)setRequestedRoster:(BOOL)flag
{
	if(flag)
		flags |= kRequestedRoster;
	else
		flags &= ~kRequestedRoster;
}

- (BOOL)hasRoster
{
	return (BOOL)(flags & kHasRoster);
}
- (void)setHasRoster:(BOOL)flag
{
	if(flag)
		flags |= kHasRoster;
	else
		flags &= ~kHasRoster;
}

- (void)fetchRoster
{
	if([self requestedRoster])
	{
		// We've already requested the roster from the server.
		return;
	}

	NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"jabber:iq:roster"];
	
	NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
	[iq addAttributeWithName:@"type" stringValue:@"get"];
	[iq addChild:query];
	
	[xmppStream sendElement:iq];
	
	[self setRequestedRoster:YES];
}

- (void)clearRoster
{
	[roster removeAllObjects];
	
	[self setRequestedRoster:NO];
	[self setHasRoster:NO];
	
	[earlyPresenceElements removeAllObjects];
}

- (void)addBuddy:(XMPPJID *)jid withNickname:(NSString *)optionalName
{
	if(jid == nil) return;
	
	if([[myJID bare] isEqualToString:[jid bare]])
	{
		// No, you don't need to add yourself
		return;
	}
	
	// Add the buddy to our roster
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
	NSXMLElement *presence = [NSXMLElement elementWithName:@"presence"];
	[presence addAttributeWithName:@"to" stringValue:[jid bare]];
	[presence addAttributeWithName:@"type" stringValue:@"subscribe"];
	
	[xmppStream sendElement:presence];
}

- (void)removeBuddy:(XMPPJID *)jid
{
	if(jid == nil) return;
	
	if([[myJID bare] isEqualToString:[jid bare]])
	{
		// No, you shouldn't remove yourself
		return;
	}
	
	// Remove the buddy from our roster
	// Unsubscribe from presence
	// And revoke contact's subscription to our presence
	// ...all in one step
	
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
	if(jid == nil) return;
	
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
	NSXMLElement *response = [NSXMLElement elementWithName:@"presence"];
	[response addAttributeWithName:@"to" stringValue:[jid bare]];
	[response addAttributeWithName:@"type" stringValue:@"subscribed"];
	
	[xmppStream sendElement:response];
	
	// Add user to our roster
	NSXMLElement *item = [NSXMLElement elementWithName:@"item"];
	[item addAttributeWithName:@"jid" stringValue:[jid bare]];
	
	NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"jabber:iq:roster"];
	[query addChild:item];
	
	NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
	[iq addAttributeWithName:@"type" stringValue:@"set"];
	[iq addChild:query];
	
	[xmppStream sendElement:iq];
	
	// Subscribe to the user's presence
	NSXMLElement *presence = [NSXMLElement elementWithName:@"presence"];
	[presence addAttributeWithName:@"to" stringValue:[jid bare]];
	[presence addAttributeWithName:@"type" stringValue:@"subscribe"];
	
	[xmppStream sendElement:presence];
}

- (void)rejectBuddyRequest:(XMPPJID *)jid
{
	// Send presence response
	NSXMLElement *response = [NSXMLElement elementWithName:@"presence"];
	[response addAttributeWithName:@"to" stringValue:[jid bare]];
	[response addAttributeWithName:@"type" stringValue:@"unsubscribed"];
	
	[xmppStream sendElement:response];
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
	
	int i;
	for(i = 0; i < [allUsers count]; i++)
	{
		XMPPUser *currentUser = [allUsers objectAtIndex:i];
		if([currentUser isOnline])
		{
			[result addObject:currentUser];
		}
	}
	
	return result;
}

- (NSArray *)unsortedUnavailableUsers
{
	NSArray *allUsers = [roster allValues];
	
	NSMutableArray *result = [NSMutableArray arrayWithCapacity:[allUsers count]];
	
	int i;
	for(i = 0; i < [allUsers count]; i++)
	{
		XMPPUser *currentUser = [allUsers objectAtIndex:i];
		if(![currentUser isOnline])
		{
			[result addObject:currentUser];
		}
	}
	
	return result;
}

- (NSArray *)sortedResources:(BOOL)includeResourcesForMyUserExcludingMyself
{
	// Add all the resouces from all the available users in the roster
	NSArray *availableUsers = [self unsortedAvailableUsers];
	
	NSMutableArray *result = [NSMutableArray arrayWithCapacity:[availableUsers count]];
	
	NSUInteger i;
	for(i = 0; i < [availableUsers count]; i++)
	{
		XMPPUser *user = [availableUsers objectAtIndex:i];
		
		[result addObjectsFromArray:[user unsortedResources]];
	}
	
	if(includeResourcesForMyUserExcludingMyself)
	{
		// Now add all the available resources from our own user account (excluding ourselves)
		
		NSArray *myResources = [myUser unsortedResources];
		
		for(i = 0; i < [myResources count]; i++)
		{
			XMPPResource *resource = [myResources objectAtIndex:i];
			
			if(![myJID isEqual:[resource jid]])
			{
				[result addObject:resource];
			}
		}
	}
	
	return [result sortedArrayUsingSelector:@selector(compare:)];
}

- (XMPPUser *)userForJID:(XMPPJID *)jid
{
	XMPPUser *result = [roster objectForKey:[jid bareJID]];
	
	if(result)
	{
		return result;
	}
	
	if([[jid bareJID] isEqual:[myJID bareJID]])
	{
		return myUser;
	}
	
	return nil;
}

- (XMPPResource *)resourceForJID:(XMPPJID *)jid
{
	XMPPUser *user = [self userForJID:jid];
	
	return [user resourceForJID:jid];
}

- (XMPPUser *)myUser
{
	return [[myUser retain] autorelease];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Sending Elements
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)sendElement:(NSXMLElement *)element
{
	[xmppStream sendElement:element];
}

- (void)sendElement:(NSXMLElement *)element andNotifyMe:(long)tag
{
	[xmppStream sendElement:element andNotifyMe:tag];
}

- (void)sendMessage:(NSString *)message toJID:(XMPPJID *)jid
{
	NSXMLElement *body = [NSXMLElement elementWithName:@"body"];
	[body setStringValue:message];

	NSXMLElement *element = [NSXMLElement elementWithName:@"message"];
	[element addAttributeWithName:@"type" stringValue:@"chat"];
	[element addAttributeWithName:@"to" stringValue:[jid full]];
	[element addChild:body];
	
	[self sendElement:element];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Delegate Helper Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)onConnecting
{
	[multicastDelegate xmppClientConnecting:self];
}

- (void)onDidConnect
{
	[multicastDelegate xmppClientDidConnect:self];
}

- (void)onDidDisconnect
{
	[multicastDelegate xmppClientDidDisconnect:self];
}

- (void)onDidRegister
{
	[multicastDelegate xmppClientDidRegister:self];
}

- (void)onDidNotRegister:(NSXMLElement *)error
{
	[multicastDelegate xmppClient:self didNotRegister:error];
}

- (void)onDidAuthenticate
{
	[multicastDelegate xmppClientDidAuthenticate:self];
}

- (void)onDidNotAuthenticate:(NSXMLElement *)error
{
	[multicastDelegate xmppClient:self didNotAuthenticate:error];
}

- (void)onDidUpdateRoster
{
	[multicastDelegate xmppClientDidUpdateRoster:self];
}

- (void)onDidReceiveBuddyRequest:(XMPPJID *)jid
{
	[multicastDelegate xmppClient:self didReceiveBuddyRequest:jid];
}

- (void)onDidReceiveIQ:(XMPPIQ *)iq
{
	[multicastDelegate xmppClient:self didReceiveIQ:iq];
}

- (void)onDidReceiveMessage:(XMPPMessage *)message
{
	[multicastDelegate xmppClient:self didReceiveMessage:message];
}

- (void)onDidReceiveError:(NSXMLElement *)error
{
	[multicastDelegate xmppClient:self didReceiveError:error];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStream Delegate Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppStreamDidOpen:(XMPPStream *)sender
{
	[self onDidConnect];
	
	if([self autoLogin])
	{
		[self authenticateUser];
	}
}

- (void)xmppStreamDidRegister:(XMPPStream *)sender
{
	[self onDidRegister];
}

- (void)xmppStream:(XMPPStream *)sender didNotRegister:(NSXMLElement *)error
{
	[self onDidNotRegister:error];
}

- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender
{
	// We're now connected and properly authenticated
	// Should we get accidentally disconnected we should automatically reconnect (if kAutoReconnect is set)
	[self setShouldReconnect:YES];
	
	// Update myUser
	[myUser release];
	myUser = [[XMPPUser alloc] initWithJID:myJID];
	
	// Note: Order matters in the calls below.
	// We request the roster FIRST, because we need the roster before we can process any presence notifications.
	// We shouldn't receive any presence notification until we've set our presence to available.
	// 
	// We notify the delegate(s) LAST because delegates may be sending their own custom
	// presence packets (and have set autoPresence to NO). The logical place for them to do so is in the
	// onDidAuthenticate method, so we try to request the roster before they start
	// sending any presence packets.
	// 
	// In the event that we do receive any presence elements prior to receiving our roster,
	// we'll be forced to store them in the earlyPresenceElements array, and process them after we finally
	// get our roster list.
	
	if([self autoRoster])
	{
		[self fetchRoster];
	}
	if([self autoPresence])
	{
		[self goOnline];
	}
	
	[self onDidAuthenticate];
}

- (void)xmppStream:(XMPPStream *)sender didNotAuthenticate:(NSXMLElement *)error
{
	[self onDidNotAuthenticate:error];
}

- (void)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
	if([iq isRosterQuery])
	{
		// Note: Some jabber servers send an iq element with a xmlns.
		// Because of the bug in Apple's NSXML (documented in our elementForName method),
		// it is important we specify the xmlns for the query.
		
		NSXMLElement *query = [iq elementForName:@"query" xmlns:@"jabber:iq:roster"];
		NSArray *items = [query elementsForName:@"item"];
		
		int i;
		for(i = 0; i < [items count]; i++)
		{
			NSXMLElement *item = (NSXMLElement *)[items objectAtIndex:i];
			
			// Filter out items for users who aren't actually in our roster.
			// That is, those users who have requested to be our buddy, but we haven't approved yet.
			if([XMPPIQ isRosterItem:item])
			{
				NSString *jidStr = [[item attributeForName:@"jid"] stringValue];
				XMPPJID *jid = [XMPPJID jidWithString:jidStr];
				
				NSString *subscription = [[item attributeForName:@"subscription"] stringValue];
				
				if([subscription isEqualToString:@"remove"])
				{
					[roster removeObjectForKey:jid];
				}
				else
				{
					XMPPUser *user = [roster objectForKey:jid];
					if(user)
					{
						[user updateWithItem:item];
					}
					else
					{
						XMPPUser *newUser = [[XMPPUser alloc] initWithItem:item];
						[roster setObject:newUser forKey:jid];
						[newUser release];
					}
				}
			}
		}
		
		[self onDidUpdateRoster];
		
		if(![self hasRoster])
		{
			// We should have our roster now
			[self setHasRoster:YES];
			
			// Which means we can process any premature presence elements we received
			for(i = 0; i < [earlyPresenceElements count]; i++)
			{
				[self xmppStream:xmppStream didReceivePresence:[earlyPresenceElements objectAtIndex:i]];
			}
			[earlyPresenceElements removeAllObjects];
		}
	}
	else
	{
		[self onDidReceiveIQ:iq];
	}
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
	[self onDidReceiveMessage:message];
}

- (void)xmppStream:(XMPPStream *)sender didReceivePresence:(XMPPPresence *)presence
{
	if(![self hasRoster])
	{
		// We received a presence notification, but we don't have a roster to apply it to yet.
		if([self requestedRoster])
		{
			// We store the presence element until we get our roster.
			[earlyPresenceElements addObject:presence];
		}
		else
		{
			// The user has not requested the roster.
			// 
			// Since the default autoRoster value is YES,
			// this means the user explicitly indicated they didn't want to automatically fetch the roster.
			// Furthermore, they haven't bothered to call the fetchRoster method,
			// but they've obviously set their presence since we're getting presence messages.
			// 
			// This means the user is probably not going to be using the roster features,
			// and so we can safely ignore this presence element.
		}
		
		return;
	}
	
	if([[presence type] isEqualToString:@"subscribe"])
	{
		XMPPUser *user = [roster objectForKey:[[presence from] bareJID]];
		
		if(user && [self autoRoster])
		{
			// Presence subscription request from someone who's already in our roster
			// Automatically approve
			
			NSXMLElement *response = [NSXMLElement elementWithName:@"presence"];
			[response addAttributeWithName:@"to" stringValue:[[presence from] bare]];
			[response addAttributeWithName:@"type" stringValue:@"subscribed"];
			
			[xmppStream sendElement:response];
		}
		else
		{
			// Presence subscription request from someone who's NOT in our roster
			
			[self onDidReceiveBuddyRequest:[presence from]];
		}
	}
	else
	{
		XMPPUser *rosterUser = [roster objectForKey:[[presence from] bareJID]];
		
		if(rosterUser)
		{
			[rosterUser updateWithPresence:presence];
		}
		else if([[myJID bareJID] isEqual:[[presence from] bareJID]])
		{
			[myUser updateWithPresence:presence];
		}
		
		[self onDidUpdateRoster];
	}
}

/**
 * There are two types of errors: TCP errors and XMPP errors.
 * If a TCP error is encountered (failure to connect, broken connection, etc) a standard NSError object is passed.
 * If an XMPP error is encountered (<stream:error> for example) an NSXMLElement object is passed.
 * 
 * Note that standard errors (<iq type='error'/> for example) are delivered normally,
 * via the other didReceive...: methods.
**/
- (void)xmppStream:(XMPPStream *)xs didReceiveError:(id)error
{
	if([error isKindOfClass:[NSError class]])
	{
		[streamError autorelease];
		streamError = [(NSError *)error copy];
		
		if([xmppStream isAuthenticated])
		{
			// We were fully connected to the XMPP server, but we've been disconnected for some reason.
			// We will wait for a few seconds or so, and then attempt to reconnect if possible
			[self performSelector:@selector(attemptReconnect:) withObject:nil afterDelay:4.0];
		}
	}
	else
	{
		// We received a <stream:error> element.
		[self onDidReceiveError:error];
	}
}

- (void)xmppStreamDidClose:(XMPPStream *)sender
{
	[self clearRoster];
	
	[myUser release];
	myUser = nil;
	
	[self onDidDisconnect];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Reconnecting
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method is invoked a few seconds after a disconnection from the server,
 * or after we receive notification that we may once again have a working internet connection.
 * If we are still disconnected, it will attempt to reconnect if the network connection appears to be online.
**/
- (void)attemptReconnect:(id)ignore
{
	NSLog(@"XMPPClient: attempReconnect method called...");
	
	if([xmppStream isDisconnected] && [self autoReconnect] && [self shouldReconnect])
	{
#if TARGET_OS_IPHONE
		[self connect];
#else
		SCNetworkConnectionFlags reachabilityStatus;
		BOOL success = SCNetworkCheckReachabilityByName("www.deusty.com", &reachabilityStatus);
		
		if(success && (reachabilityStatus & kSCNetworkFlagsReachable))
		{
			[self connect];
		}
#endif
	}
}

- (void)networkStatusDidChange:(NSNotification *)notification
{
	// The following information needs to be tested using multiple interfaces
	
	// If this is a notification of a lost internet connection, there won't be a userInfo
	// Otherwise, there will be...I think...
	
	if([notification userInfo])
	{
		// We may have an internet connection now...
		// 
		// If we were accidentally disconnected (user didn't tell us to disconnect)
		// then now would be a good time to attempt to reconnect.
		if([self shouldReconnect])
		{
			// We will wait for a few seconds or so, and then attempt to reconnect if possible
			[self performSelector:@selector(attemptReconnect:) withObject:nil afterDelay:4.0];
		}
	}
}

@end
