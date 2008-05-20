#import "XMPPClient.h"
#import "XMPPStream.h"
#import "XMPPJID.h"
#import "XMPPUser.h"
#import "XMPPResource.h"
#import "XMPPIQ.h"
#import "XMPPMessage.h"
#import "XMPPPresence.h"
#import "NSXMLElementAdditions.h"


@interface XMPPClient (PrivateAPI)

- (void)notifyDelegates_Connecting;
- (void)notifyDelegates_DidConnect;
- (void)notifyDelegates_DidDisconnect;
- (void)notifyDelegates_DidRegister;
- (void)notifyDelegates_DidNotRegister:(NSXMLElement *)error;
- (void)notifyDelegates_DidAuthenticate;
- (void)notifyDelegates_DidNotAuthenticate:(NSXMLElement *)error;
- (void)notifyDelegates_DidUpdateRoster;
- (void)notifyDelegates_DidReceiveBuddyRequest:(XMPPJID *)jid;
- (void)notifyDelegates_DidReceiveIQ:(XMPPIQ *)iq;
- (void)notifyDelegates_DidReceiveMessage:(XMPPMessage *)message;

@end

@implementation XMPPClient

- (id)init
{
	if(self = [super init])
	{
		delegates = [[NSMutableArray alloc] initWithCapacity:1];
		
		priority = 1;
		
		autoLogin = YES;
		allowsPlaintextAuth = YES;
		autoPresence = YES;
		autoRoster = YES;
		autoReconnect = YES;
		
		xmppStream = [[XMPPStream alloc] initWithDelegate:self];
		
		roster = [[NSMutableDictionary alloc] initWithCapacity:10];
	}
	return self;
}

- (void)dealloc
{
	[delegates release];
	
	[domain release];
	[myJID release];
	[password release];
	
	[xmppStream setDelegate:nil];
	[xmppStream disconnect];
	[xmppStream release];
	
	[roster release];
	
	[super dealloc];
}

- (void)addDelegate:(id)delegate
{
	[delegates addObject:delegate];
}

- (void)removeDelegate:(id)delegate
{
	[delegates removeObject:delegate];
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
	return usesOldStyleSSL;
}
- (void)setUsesOldStyleSSL:(BOOL)flag
{
	usesOldStyleSSL = flag;
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
	return autoLogin;
}
- (void)setAutoLogin:(BOOL)flag
{
	autoLogin = flag;
}

- (BOOL)autoPresence
{
	return autoPresence;
}
- (void)setAutoPresence:(BOOL)flag
{
	autoPresence = flag;
}

- (BOOL)autoRoster
{
	return autoRoster;
}
- (void)setAutoRoster:(BOOL)flag
{
	autoRoster = flag;
}

- (BOOL)autoReconnect
{
	return autoReconnect;
}
- (void)setAutoReconnect:(BOOL)flag
{
	autoReconnect = flag;
}

- (void)connect
{
	[self notifyDelegates_Connecting];
	
	if(usesOldStyleSSL)
		[xmppStream connectToSecureHost:domain onPort:port withVirtualHost:[myJID domain]];
	else
		[xmppStream connectToHost:domain onPort:port withVirtualHost:[myJID domain]];
}

- (void)disconnect
{
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
	return allowsPlaintextAuth;
}
- (void)setAllowsPlaintextAuth:(BOOL)flag
{
	allowsPlaintextAuth = flag;
}

- (void)authenticateUser
{
	if(!allowsPlaintextAuth)
	{
		if(![xmppStream isSecure] && ![xmppStream supportsDigestMD5Authentication])
		{
			// The only way to login is via plaintext!
			return;
		}
	}
	
	[xmppStream authenticateUser:[myJID user] withPassword:password resource:[myJID resource]];
}

- (BOOL)isAuthenticated
{
	return [xmppStream isAuthenticated];
}

- (void)goOnline
{
	NSXMLElement *presence = [NSXMLElement elementWithName:@"presence"];
	
	[xmppStream sendElement:presence];
}

- (void)goOffline
{
	// Send offline presence element
	NSXMLElement *presence = [NSXMLElement elementWithName:@"presence"];
	[presence addAttribute:[NSXMLNode attributeWithName:@"type" stringValue:@"unavailable"]];
	
	[xmppStream sendElement:presence];
	
	// Remove all users from our roster when we're offline.
	// We don't receive presence notifications when we're offline.
	
	BOOL didUpdateRoster = ([roster count] > 0);
	[roster removeAllObjects];
	
	if(didUpdateRoster)
	{
		[self notifyDelegates_DidUpdateRoster];
	}
}

- (void)fetchRoster
{
	NSXMLElement *query = [NSXMLElement elementWithName:@"query"];
	[query addAttribute:[NSXMLNode attributeWithName:@"xmlns" stringValue:@"jabber:iq:roster"]];
	
	NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
	[iq addAttribute:[NSXMLNode attributeWithName:@"type" stringValue:@"get"]];
	[iq addChild:query];
	
	[xmppStream sendElement:iq];
}

- (void)addBuddy:(XMPPJID *)jid withNickname:(NSString *)optionalName
{
	if(jid == nil) return;
	
	// Add the buddy to our roster
	NSXMLElement *item = [NSXMLElement elementWithName:@"item"];
	[item addAttribute:[NSXMLNode attributeWithName:@"jid" stringValue:[jid bare]]];
	if(optionalName)
	{
		[item addAttribute:[NSXMLNode attributeWithName:@"name" stringValue:optionalName]];
	}
	
	NSXMLElement *query = [NSXMLElement elementWithName:@"query"];
	[query addAttribute:[NSXMLNode attributeWithName:@"xmlns" stringValue:@"jabber:iq:roster"]];
	[query addChild:item];
		
	NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
	[iq addAttribute:[NSXMLNode attributeWithName:@"type" stringValue:@"set"]];
	[iq addChild:query];
	
	[xmppStream sendElement:iq];
	
	// Subscribe to the buddy's presence
	NSXMLElement *presence = [NSXMLElement elementWithName:@"presence"];
	[presence addAttribute:[NSXMLNode attributeWithName:@"to" stringValue:[jid bare]]];
	[presence addAttribute:[NSXMLNode attributeWithName:@"type" stringValue:@"subscribe"]];
	
	[xmppStream sendElement:presence];
}

- (void)removeBuddy:(XMPPJID *)jid
{
	if(jid == nil) return;
	
	// Remove the buddy from our roster
	// Unsubscribe from presence
	// And revoke contact's subscription to our presence
	// ...all in one step
	
	NSXMLElement *item = [NSXMLElement elementWithName:@"item"];
	[item addAttribute:[NSXMLNode attributeWithName:@"jid" stringValue:[jid bare]]];
	[item addAttribute:[NSXMLNode attributeWithName:@"subscription" stringValue:@"remove"]];
	
	NSXMLElement *query = [NSXMLElement elementWithName:@"query"];
	[query addAttribute:[NSXMLNode attributeWithName:@"xmlns" stringValue:@"jabber:iq:roster"]];
	[query addChild:item];
	
	NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
	[iq addAttribute:[NSXMLNode attributeWithName:@"type" stringValue:@"set"]];
	[iq addChild:query];
	
	[xmppStream sendElement:iq];
}

- (void)setNickname:(NSString *)nickname forBuddy:(XMPPJID *)jid
{
	if(jid == nil) return;
	
	NSXMLElement *item = [NSXMLElement elementWithName:@"item"];
	[item addAttribute:[NSXMLNode attributeWithName:@"jid" stringValue:[jid bare]]];
	[item addAttribute:[NSXMLNode attributeWithName:@"name" stringValue:nickname]];
	
	NSXMLElement *query = [NSXMLElement elementWithName:@"query"];
	[query addAttribute:[NSXMLNode attributeWithName:@"xmlns" stringValue:@"jabber:iq:roster"]];
	[query addChild:item];
	
	NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
	[iq addAttribute:[NSXMLNode attributeWithName:@"type" stringValue:@"set"]];
	[iq addChild:query];
	
	[xmppStream sendElement:iq];
}

- (void)acceptBuddyRequest:(XMPPJID *)jid
{
	// Send presence response
	NSXMLElement *response = [NSXMLElement elementWithName:@"presence"];
	[response addAttribute:[NSXMLNode attributeWithName:@"to" stringValue:[jid bare]]];
	[response addAttribute:[NSXMLNode attributeWithName:@"type" stringValue:@"subscribed"]];
	
	[xmppStream sendElement:response];
	
	// Add user to our roster
	NSXMLElement *item = [NSXMLElement elementWithName:@"item"];
	[item addAttribute:[NSXMLNode attributeWithName:@"jid" stringValue:[jid bare]]];
	
	NSXMLElement *query = [NSXMLElement elementWithName:@"query"];
	[query addAttribute:[NSXMLNode attributeWithName:@"xmlns" stringValue:@"jabber:iq:roster"]];
	[query addChild:item];
	
	NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
	[iq addAttribute:[NSXMLNode attributeWithName:@"type" stringValue:@"set"]];
	[iq addChild:query];
	
	[xmppStream sendElement:iq];
	
	// Subscribe to the user's presence
	NSXMLElement *presence = [NSXMLElement elementWithName:@"presence"];
	[presence addAttribute:[NSXMLNode attributeWithName:@"to" stringValue:[jid bare]]];
	[presence addAttribute:[NSXMLNode attributeWithName:@"type" stringValue:@"subscribe"]];
	
	[xmppStream sendElement:presence];
}

- (void)rejectBuddyRequest:(XMPPJID *)jid
{
	// Send presence response
	NSXMLElement *response = [NSXMLElement elementWithName:@"presence"];
	[response addAttribute:[NSXMLNode attributeWithName:@"to" stringValue:[jid bare]]];
	[response addAttribute:[NSXMLNode attributeWithName:@"type" stringValue:@"unsubscribed"]];
	
	[xmppStream sendElement:response];
}

- (void)sendElement:(NSXMLElement *)element
{
	[xmppStream sendElement:element];
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
	
	return [result sortedArrayUsingSelector:@selector(compareByName:)];
}

- (NSArray *)sortedUnavailableUserByName
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
	
	return [result sortedArrayUsingSelector:@selector(compareByName:)];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Delegate Helper Methods:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)notifyDelegates_Connecting
{
	int i;
	for(i = 0; i < [delegates count]; i++)
	{
		id currentDelegate = [delegates objectAtIndex:i];
		
		if([currentDelegate respondsToSelector:@selector(xmppClientConnecting:)])
		{
			[currentDelegate xmppClientConnecting:self];
		}
	}
}

- (void)notifyDelegates_DidConnect
{
	int i;
	for(i = 0; i < [delegates count]; i++)
	{
		id currentDelegate = [delegates objectAtIndex:i];
		
		if([currentDelegate respondsToSelector:@selector(xmppClientDidConnect:)])
		{
			[currentDelegate xmppClientDidConnect:self];
		}
	}
}

- (void)notifyDelegates_DidDisconnect
{
	int i;
	for(i = 0; i < [delegates count]; i++)
	{
		id currentDelegate = [delegates objectAtIndex:i];
		
		if([currentDelegate respondsToSelector:@selector(xmppClientDidDisconnect:)])
		{
			[currentDelegate xmppClientDidDisconnect:self];
		}
	}
}

- (void)notifyDelegates_DidRegister
{
	int i;
	for(i = 0; i < [delegates count]; i++)
	{
		id currentDelegate = [delegates objectAtIndex:i];
		
		if([currentDelegate respondsToSelector:@selector(xmppClientDidRegister:)])
		{
			[currentDelegate xmppClientDidRegister:self];
		}
	}
}

- (void)notifyDelegates_DidNotRegister:(NSXMLElement *)error
{
	int i;
	for(i = 0; i < [delegates count]; i++)
	{
		id currentDelegate = [delegates objectAtIndex:i];
		
		if([currentDelegate respondsToSelector:@selector(xmppClient:didNotRegister:)])
		{
			[currentDelegate xmppClient:self didNotRegister:error];
		}
	}
}

- (void)notifyDelegates_DidAuthenticate
{
	int i;
	for(i = 0; i < [delegates count]; i++)
	{
		id currentDelegate = [delegates objectAtIndex:i];
		
		if([currentDelegate respondsToSelector:@selector(xmppClientDidAuthenticate:)])
		{
			[currentDelegate xmppClientDidAuthenticate:self];
		}
	}
}

- (void)notifyDelegates_DidNotAuthenticate:(NSXMLElement *)error
{
	int i;
	for(i = 0; i < [delegates count]; i++)
	{
		id currentDelegate = [delegates objectAtIndex:i];
		
		if([currentDelegate respondsToSelector:@selector(xmppClient:didNotAuthenticate:)])
		{
			[currentDelegate xmppClient:self didNotAuthenticate:error];
		}
	}
}

- (void)notifyDelegates_DidUpdateRoster
{
	NSLog(@"---------- XMPPClient: notifyDelegates_DidUpdateRoster");
	
	int i;
	for(i = 0; i < [delegates count]; i++)
	{
		id currentDelegate = [delegates objectAtIndex:i];
		
		if([currentDelegate respondsToSelector:@selector(xmppClientDidUpdateRoster:)])
		{
			[currentDelegate xmppClientDidUpdateRoster:self];
		}
	}
}

- (void)notifyDelegates_DidReceiveBuddyRequest:(XMPPJID *)jid
{
	int i;
	for(i = 0; i < [delegates count]; i++)
	{
		id currentDelegate = [delegates objectAtIndex:i];
		
		if([currentDelegate respondsToSelector:@selector(xmppClient:didReceiveBuddyRequest:)])
		{
			[currentDelegate xmppClient:self didReceiveBuddyRequest:jid];
		}
	}
}

- (void)notifyDelegates_DidReceiveIQ:(XMPPIQ *)iq
{
	int i;
	for(i = 0; i < [delegates count]; i++)
	{
		id currentDelegate = [delegates objectAtIndex:i];
		
		if([currentDelegate respondsToSelector:@selector(xmppClient:didReceiveIQ:)])
		{
			[currentDelegate xmppClient:self didReceiveIQ:iq];
		}
	}
}

- (void)notifyDelegates_DidReceiveMessage:(XMPPMessage *)message
{
	int i;
	for(i = 0; i < [delegates count]; i++)
	{
		id currentDelegate = [delegates objectAtIndex:i];
		
		if([currentDelegate respondsToSelector:@selector(xmppClient:didReceiveMessage:)])
		{
			[currentDelegate xmppClient:self didReceiveMessage:message];
		}
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStream Delegate Methods:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppStreamDidOpen:(XMPPStream *)sender
{
	[self notifyDelegates_DidConnect];
	
	if(autoLogin)
	{
		[self authenticateUser];
	}
}

- (void)xmppStreamDidRegister:(XMPPStream *)sender
{
	[self notifyDelegates_DidRegister];
}

- (void)xmppStream:(XMPPStream *)sender didNotRegister:(NSXMLElement *)error
{
	[self notifyDelegates_DidNotRegister:error];
}

- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender
{
	[self notifyDelegates_DidAuthenticate];
	
	if(autoRoster)
	{
		[self fetchRoster];
	}
	if(autoPresence)
	{
		[self goOnline];
	}
}

- (void)xmppStream:(XMPPStream *)sender didNotAuthenticate:(NSXMLElement *)error
{
	[self notifyDelegates_DidNotAuthenticate:error];
}

- (void)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
	if([iq isRosterQuery])
	{
		NSXMLElement *query = [iq elementForName:@"query"];
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
		
		[self notifyDelegates_DidUpdateRoster];
	}
	else
	{
		[self notifyDelegates_DidReceiveIQ:iq];
	}
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
	[self notifyDelegates_DidReceiveMessage:message];
}

- (void)xmppStream:(XMPPStream *)sender didReceivePresence:(XMPPPresence *)presence
{
	if([[presence type] isEqualToString:@"subscribe"])
	{
		XMPPUser *user = [roster objectForKey:[[presence from] bareJID]];
		
		if(user && autoRoster)
		{
			// Presence subscription request from someone who's already in our roster
			// Automatically approve
			
			NSXMLElement *response = [NSXMLElement elementWithName:@"presence"];
			[response addAttribute:[NSXMLNode attributeWithName:@"to" stringValue:[[presence from] bare]]];
			[response addAttribute:[NSXMLNode attributeWithName:@"type" stringValue:@"subscribed"]];
			
			[xmppStream sendElement:response];
		}
		else
		{
			// Presence subscription request from someone who's NOT in our roster
			
			[self notifyDelegates_DidReceiveBuddyRequest:[presence from]];
		}
	}
	else
	{
		XMPPUser *user = [roster objectForKey:[[presence from] bareJID]];
		[user updateWithPresence:presence];
		
		[self notifyDelegates_DidUpdateRoster];
	}
}

- (void)xmppStreamDidClose:(XMPPStream *)sender
{
	[roster removeAllObjects];
	[self notifyDelegates_DidDisconnect];
}

@end
