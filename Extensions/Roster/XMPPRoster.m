#import "XMPPRoster.h"
#import "XMPP.h"
#import "XMPPLogging.h"
#import "XMPPFramework.h"
#import "DDList.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

// Log levels: off, error, warn, info, verbose
// Log flags: trace
#if DEBUG
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN; // | XMPP_LOG_FLAG_TRACE;
#else
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

enum XMPPRosterConfig
{
	kAutoFetchRoster = 1 << 0,                   // If set, we automatically fetch roster after authentication
	kAutoAcceptKnownPresenceSubscriptionRequests = 1 << 1, // See big description in header file... :D
	kRosterlessOperation = 1 << 2,
};
enum XMPPRosterFlags
{
	kRequestedRoster = 1 << 0,  // If set, we have requested the roster
	kHasRoster       = 1 << 1,  // If set, we have received the roster
    kPopulatingRoster = 1 << 2,  // If set, we are populating the roster
};

@interface XMPPRoster (PrivateAPI)

- (void)xmppStream:(XMPPStream *)sender didReceivePresence:(XMPPPresence *)presence;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPRoster

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
			xmppRosterStorage = storage;
		}
		else
		{
			XMPPLogError(@"%@: %@ - Unable to configure storage!", THIS_FILE, THIS_METHOD);
		}
		
		config = kAutoFetchRoster | kAutoAcceptKnownPresenceSubscriptionRequests;
		flags = 0;
		
		earlyPresenceElements = [[NSMutableArray alloc] initWithCapacity:2];
		
		mucModules = [[DDList alloc] init];
	}
	return self;
}

- (BOOL)activate:(XMPPStream *)aXmppStream
{
	XMPPLogTrace();
	
	if ([super activate:aXmppStream])
	{
		XMPPLogVerbose(@"%@: Activated", THIS_FILE);
		
		#ifdef _XMPP_VCARD_AVATAR_MODULE_H
		{
			// Automatically tie into the vCard system so we can store user photos.
			
			[xmppStream autoAddDelegate:self
			              delegateQueue:moduleQueue
			           toModulesOfClass:[XMPPvCardAvatarModule class]];
		}
		#endif
		
		#ifdef _XMPP_MUC_H
		{
			// Automatically tie into the MUC system so we can ignore non-roster presence stanzas.
			
			[xmppStream enumerateModulesWithBlock:^(XMPPModule *module, NSUInteger idx, BOOL *stop) {
				
				if ([module isKindOfClass:[XMPPMUC class]])
				{
					[mucModules add:(__bridge void *)module];
				}
			}];
		}
		#endif
		
		return YES;
	}
	
	return NO;
}

- (void)deactivate
{
	XMPPLogTrace();
	
	#ifdef _XMPP_VCARD_AVATAR_MODULE_H
	{
		[xmppStream removeAutoDelegate:self delegateQueue:moduleQueue fromModulesOfClass:[XMPPvCardAvatarModule class]];
	}
	#endif
	
	[super deactivate];
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Internal
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method may optionally be used by XMPPRosterStorage classes (declared in XMPPRosterPrivate.h).
**/
- (GCDMulticastDelegate *)multicastDelegate
{
	return multicastDelegate;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Configuration
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (id <XMPPRosterStorage>)xmppRosterStorage
{
	// Note: The xmppRosterStorage variable is read-only (set in the init method)
	
	return xmppRosterStorage;
}

- (BOOL)autoFetchRoster
{
	__block BOOL result = NO;
	
	dispatch_block_t block = ^{
		result = (config & kAutoFetchRoster) ? YES : NO;
	};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_sync(moduleQueue, block);
	
	return result;
}

- (void)setAutoFetchRoster:(BOOL)flag
{
	dispatch_block_t block = ^{
		
		if (flag)
			config |= kAutoFetchRoster;
		else
			config &= ~kAutoFetchRoster;
	};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (BOOL)autoAcceptKnownPresenceSubscriptionRequests
{
	__block BOOL result = NO;
	
	dispatch_block_t block = ^{
		result = (config & kAutoAcceptKnownPresenceSubscriptionRequests) ? YES : NO;
	};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_sync(moduleQueue, block);
	
	return result;
}

- (void)setAutoAcceptKnownPresenceSubscriptionRequests:(BOOL)flag
{
	dispatch_block_t block = ^{
		
		if (flag)
			config |= kAutoAcceptKnownPresenceSubscriptionRequests;
		else
			config &= ~kAutoAcceptKnownPresenceSubscriptionRequests;
	};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (BOOL)allowRosterlessOperation
{
	__block BOOL result = NO;
	
	dispatch_block_t block = ^{
		result = (config & kRosterlessOperation) ? YES : NO;
	};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_sync(moduleQueue, block);
	
	return result;
}

- (void)setAllowRosterlessOperation:(BOOL)flag
{
	dispatch_block_t block = ^{
		
		if (flag)
			config |= kRosterlessOperation;
		else
			config &= ~kRosterlessOperation;
	};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}


- (BOOL)hasRequestedRoster
{
	__block BOOL result = NO;
	
	dispatch_block_t block = ^{
		result = (flags & kRequestedRoster) ? YES : NO;
	};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_sync(moduleQueue, block);
	
	return result;
}

- (BOOL)isPopulating{
    
    __block BOOL result = NO;
	
	dispatch_block_t block = ^{
		result = (flags & kPopulatingRoster) ? YES : NO;
	};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_sync(moduleQueue, block);
	
	return result;
}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)_requestedRoster
{
	NSAssert(dispatch_get_specific(moduleQueueTag) , @"Invoked on incorrect queue");
	
	return (flags & kRequestedRoster) ? YES : NO;
}

- (void)_setRequestedRoster:(BOOL)flag
{
	NSAssert(dispatch_get_specific(moduleQueueTag) , @"Invoked on incorrect queue");
	
	if (flag)
		flags |= kRequestedRoster;
	else
		flags &= ~kRequestedRoster;
}

- (BOOL)_hasRoster
{
	NSAssert(dispatch_get_specific(moduleQueueTag) , @"Invoked on incorrect queue");
	
	return (flags & kHasRoster) ? YES : NO;
}

- (void)_setHasRoster:(BOOL)flag
{
	NSAssert(dispatch_get_specific(moduleQueueTag) , @"Invoked on incorrect queue");
	
	if (flag)
		flags |= kHasRoster;
	else
		flags &= ~kHasRoster;
}

- (BOOL)_populatingRoster
{
	NSAssert(dispatch_get_specific(moduleQueueTag) , @"Invoked on incorrect queue");
	
	return (flags & kPopulatingRoster) ? YES : NO;
}

- (void)_setPopulatingRoster:(BOOL)flag
{
	NSAssert(dispatch_get_specific(moduleQueueTag) , @"Invoked on incorrect queue");
	
	if (flag)
		flags |= kPopulatingRoster;
	else
		flags &= ~kPopulatingRoster;
}
/**
 * Some server's include in our roster the JID's of user's NOT in our roster.
 * This happens when another user adds us to their roster, and requests permission to receive our presence.
 * 
 * As discussed in RFC 3921, the state of the other user is "None + Pending In",
 * and the server "SHOULD NOT" include these JID's in the roster it sends us.
 * 
 * Nonetheless, some servers do anyway.
 * This method filters out such rogue entries in our roster.
 * 
 * Note that the server will automatically send us the proper presence subscription request,
 * and it will continue to do so everytime we sign in.
 * From the RFC:
 *     the user's server MUST keep a record of the subscription request and deliver the request when the
 *     user next creates an available resource, until the user either approves or denies the request.
 * 
 * So there is absolutely NO reason to process these entries, or include them in the roster's storage.
 * Furthermore, it isn't reliable to depend on these entires being there.
 * The RFC has clearly defined recommendations on the matter, and servers that currently send these rogue items
 * may very likely stop doing so in future versions.
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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Roster Management
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)addUser:(XMPPJID *)jid withNickname:(NSString *)optionalName{
	[self addUser:jid withNickname:optionalName groups:nil subscribeToPresence:YES];
}

- (void)addUser:(XMPPJID *)jid withNickname:(NSString *)optionalName groups:(NSArray *)groups{
	[self addUser:jid withNickname:optionalName groups:groups subscribeToPresence:YES];
}

- (void)addUser:(XMPPJID *)jid withNickname:(NSString *)optionalName groups:(NSArray *)groups subscribeToPresence:(BOOL)subscribe{
	
	if (jid == nil) return;

	XMPPJID *myJID = xmppStream.myJID;

	if ([myJID isEqualToJID:jid options:XMPPJIDCompareBare])
	{
		// You don't need to add yourself to the roster.
		// XMPP will automatically send you presence from all resources signed in under your username.
		//
		// E.g. If you sign in with robbiehanson@deusty.com/home you'll automatically
		//    receive presence from robbiehanson@deusty.com/work
		
		XMPPLogInfo(@"%@: %@ - Ignoring request to add myself to my own roster", [self class], THIS_METHOD);
		return;
	}

	// Add the buddy to our roster
	//
	// <iq type="set">
	//   <query xmlns="jabber:iq:roster">
	//     <item jid="bareJID" name="optionalName">
	//      <group>family</group>
	//     </item>
	//   </query>
	// </iq>

	NSXMLElement *item = [NSXMLElement elementWithName:@"item"];
	[item addAttributeWithName:@"jid" stringValue:[jid bare]];

	if(optionalName)
	{
		[item addAttributeWithName:@"name" stringValue:optionalName];
	}

	for (NSString *group in groups) {
		NSXMLElement *groupElement = [NSXMLElement elementWithName:@"group"];
		[groupElement setStringValue:group];
		[item addChild:groupElement];
	}

	NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"jabber:iq:roster"];
	[query addChild:item];

	NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
	[iq addAttributeWithName:@"type" stringValue:@"set"];
	[iq addChild:query];

	[xmppStream sendElement:iq];

	if(subscribe)
	{
		[self subscribePresenceToUser:jid];
	}
}

- (void)setNickname:(NSString *)nickname forUser:(XMPPJID *)jid
{
	// This is a public method, so it may be invoked on any thread/queue.
	
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
	
	XMPPIQ *iq = [XMPPIQ iqWithType:@"set"];
	[iq addChild:query];
	
	[xmppStream sendElement:iq];
}

- (void)subscribePresenceToUser:(XMPPJID *)jid
{
	// This is a public method, so it may be invoked on any thread/queue.
	
	if (jid == nil) return;
	
	XMPPJID *myJID = xmppStream.myJID;
	
	if ([myJID isEqualToJID:jid options:XMPPJIDCompareBare])
	{
		XMPPLogInfo(@"%@: %@ - Ignoring request to subscribe presence to myself", [self class], THIS_METHOD);
		return;
	}
	
	// <presence to='bareJID' type='subscribe'/>
	
	XMPPPresence *presence = [XMPPPresence presenceWithType:@"subscribe" to:[jid bareJID]];
	[xmppStream sendElement:presence];
}

- (void)unsubscribePresenceFromUser:(XMPPJID *)jid
{
	// This is a public method, so it may be invoked on any thread/queue.
	
	if (jid == nil) return;
	
	XMPPJID *myJID = xmppStream.myJID;
	
	if ([myJID isEqualToJID:jid options:XMPPJIDCompareBare])
	{
		XMPPLogInfo(@"%@: %@ - Ignoring request to unsubscribe presence from myself", [self class], THIS_METHOD);
		return;
	}
	
	// <presence to="bareJID" type="unsubscribe">
	
	XMPPPresence *presence = [XMPPPresence presenceWithType:@"unsubscribe" to:[jid bareJID]];
	[xmppStream sendElement:presence];
}

- (void)revokePresencePermissionFromUser:(XMPPJID *)jid
{
	// This is a public method, so it may be invoked on any thread/queue.
	
	if (jid == nil) return;
	
	XMPPJID *myJID = xmppStream.myJID;
	
	if ([myJID isEqualToJID:jid options:XMPPJIDCompareBare])
	{
		XMPPLogInfo(@"%@: %@ - Ignoring request to revoke presence from myself", [self class], THIS_METHOD);
		return;
	}
	
	// <presence to="bareJID" type="unsubscribed">
	
	XMPPPresence *presence = [XMPPPresence presenceWithType:@"unsubscribed" to:[jid bareJID]];
	[xmppStream sendElement:presence];
}

- (void)removeUser:(XMPPJID *)jid
{
	// This is a public method, so it may be invoked on any thread/queue.
	
	if (jid == nil) return;
	
	XMPPJID *myJID = xmppStream.myJID;
	
	if ([myJID isEqualToJID:jid options:XMPPJIDCompareBare])
	{
		XMPPLogInfo(@"%@: %@ - Ignoring request to remove myself from my own roster", [self class], THIS_METHOD);
		return;
	}
	
	// Remove the user from our roster.
	// And unsubscribe from presence.
	// And revoke contact's subscription to our presence.
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
	
	XMPPIQ *iq = [XMPPIQ iqWithType:@"set"];
	[iq addChild:query];
	
	[xmppStream sendElement:iq];
}

- (void)acceptPresenceSubscriptionRequestFrom:(XMPPJID *)jid andAddToRoster:(BOOL)flag
{
	// This is a public method, so it may be invoked on any thread/queue.
	
	// Send presence response
	// 
	// <presence to="bareJID" type="subscribed"/>
	
	XMPPPresence *presence = [XMPPPresence presenceWithType:@"subscribed" to:[jid bareJID]];
	[xmppStream sendElement:presence];
	
	// Add optionally add user to our roster
	
	if (flag)
	{
		[self addUser:jid withNickname:nil];
	}
}

- (void)rejectPresenceSubscriptionRequestFrom:(XMPPJID *)jid
{
	// This is a public method, so it may be invoked on any thread/queue.
	
	// Send presence response
	// 
	// <presence to="bareJID" type="unsubscribed"/>
	
	XMPPPresence *presence = [XMPPPresence presenceWithType:@"unsubscribed" to:[jid bareJID]];
	[xmppStream sendElement:presence];
}

- (void)fetchRoster
{
	// This is a public method, so it may be invoked on any thread/queue.
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		if ([self _requestedRoster])
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
		
		[self _setRequestedRoster:YES];
	}};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStream Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender
{
	// This method is invoked on the moduleQueue.
	
	XMPPLogTrace();
	
	if ([self autoFetchRoster])
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
		BOOL hasRoster = [self _hasRoster];
		
		if (!hasRoster)
		{
            [self _setPopulatingRoster:YES];
            [multicastDelegate xmppRosterDidBeginPopulating:self];
			[xmppRosterStorage beginRosterPopulationForXMPPStream:xmppStream];
		}
		
		NSArray *items = [query elementsForName:@"item"];
		for (NSXMLElement *item in items)
		{
			// During roster population, we need to filter out items for users who aren't actually in our roster.
			// That is, those users who have requested to be our buddy, but we haven't approved yet.
			// This is described in more detail in the method isRosterItem above.
			
            [multicastDelegate xmppRoster:self didRecieveRosterItem:item];
            
			if (hasRoster || [self isRosterItem:item])
			{
				[xmppRosterStorage handleRosterItem:item xmppStream:xmppStream];
			}
		}
		
		if (!hasRoster)
		{
			// We should have our roster now
			
			[self _setHasRoster:YES];
            [self _setPopulatingRoster:NO];
            [multicastDelegate xmppRosterDidEndPopulating:self];
			[xmppRosterStorage endRosterPopulationForXMPPStream:xmppStream];
			
			// Process any premature presence elements we received.
			
			for (XMPPPresence *presence in earlyPresenceElements)
			{
				[self xmppStream:xmppStream didReceivePresence:presence];
			}
			[earlyPresenceElements removeAllObjects];
		}
		
		return YES;
	}
	
	return NO;
}

- (void)xmppStream:(XMPPStream *)sender didReceivePresence:(XMPPPresence *)presence
{
	// This method is invoked on the moduleQueue.
	
	XMPPLogTrace();
	
	if (![self _hasRoster] && ![self allowRosterlessOperation])
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
		
		if ([self _requestedRoster])
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
		XMPPJID *userJID = [[presence from] bareJID];
		
		BOOL knownUser = [xmppRosterStorage userExistsWithJID:userJID xmppStream:xmppStream];
		
		if (knownUser && [self autoAcceptKnownPresenceSubscriptionRequests])
		{
			// Presence subscription request from someone who's already in our roster.
			// Automatically approve.
			// 
			// <presence to="bareJID" type="subscribed"/>
			
			XMPPPresence *response = [XMPPPresence presenceWithType:@"subscribed" to:userJID];
			[xmppStream sendElement:response];
		}
		else
		{
			// Presence subscription request from someone who's NOT in our roster
			
			[multicastDelegate xmppRoster:self didReceivePresenceSubscriptionRequest:presence];
		}
	}
	else
	{
		#ifdef _XMPP_MUC_H
		
		// Ignore MUC related presence items
		
		for (XMPPMUC *muc in mucModules)
		{
			if ([muc isMUCRoomPresence:presence])
			{
				return;
			}
		}
		
		#endif
		
		[xmppRosterStorage handlePresence:presence xmppStream:xmppStream];
	}
}

- (void)xmppStream:(XMPPStream *)sender didSendPresence:(XMPPPresence *)presence
{
	// This method is invoked on the moduleQueue.
	
	XMPPLogTrace();
	
	// We check the toStr, so we don't dump the resources when a user leaves a MUC room.
	
	if ([[presence type] isEqualToString:@"unavailable"] && [presence toStr] == nil)
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
	
	[self _setRequestedRoster:NO];
	[self _setHasRoster:NO];
	
	[earlyPresenceElements removeAllObjects];
}

#ifdef _XMPP_MUC_H

- (void)xmppStream:(XMPPStream *)sender didRegisterModule:(id)module
{
	if ([module isKindOfClass:[XMPPMUC class]])
	{
		if (![mucModules contains:(__bridge void *)module])
		{
			[mucModules add:(__bridge void *)module];
		}
	}
}

- (void)xmppStream:(XMPPStream *)sender willUnregisterModule:(id)module
{
	if ([module isKindOfClass:[XMPPMUC class]])
	{
		[mucModules remove:(__bridge void *)module];
	}
}

#endif

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPvCardAvatarDelegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#ifdef _XMPP_VCARD_AVATAR_MODULE_H

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
	if ([xmppRosterStorage respondsToSelector:@selector(setPhoto:forUserWithJID:xmppStream:)])
	{
		[xmppRosterStorage setPhoto:photo forUserWithJID:[jid bareJID] xmppStream:xmppStream];
	}
}

#endif

@end
