#import "XMPPRosterCoreDataStorage.h"
#import "XMPPGroupCoreDataStorageObject.h"
#import "XMPPUserCoreDataStorageObject.h"
#import "XMPPResourceCoreDataStorageObject.h"
#import "XMPPRosterPrivate.h"
#import "XMPPCoreDataStorageProtected.h"
#import "XMPP.h"
#import "XMPPLogging.h"
#import "NSNumber+XMPP.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

// Log levels: off, error, warn, info, verbose
#if DEBUG
  static const int xmppLogLevel = XMPP_LOG_LEVEL_INFO; // | XMPP_LOG_FLAG_TRACE;
#else
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

#define AssertPrivateQueue() \
        NSAssert(dispatch_get_specific(storageQueueTag), @"Private method: MUST run on storageQueue");


@implementation XMPPRosterCoreDataStorage

static XMPPRosterCoreDataStorage *sharedInstance;

+ (instancetype)sharedInstance
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		
		sharedInstance = [[XMPPRosterCoreDataStorage alloc] initWithDatabaseFilename:nil storeOptions:nil];
	});
	
	return sharedInstance;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Setup
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)commonInit
{
	XMPPLogTrace();
	[super commonInit];
	
	// This method is invoked by all public init methods of the superclass
    autoRemovePreviousDatabaseFile = YES;
	autoRecreateDatabaseFile = YES;
    
	rosterPopulationSet = [[NSMutableSet alloc] init];
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
			parentQueueTag = &parentQueueTag;
			dispatch_queue_set_specific(parentQueue, parentQueueTag, parentQueueTag, NULL);
			
#if !OS_OBJECT_USE_OBJC
			dispatch_retain(parentQueue);
#endif
			
			return YES;
		}
	}
    
    return NO;
}

- (void)dealloc
{
#if !OS_OBJECT_USE_OBJC
	if (parentQueue)
		dispatch_release(parentQueue);
#endif
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)_clearAllResourcesForXMPPStream:(XMPPStream *)stream
{
	XMPPLogTrace();
	AssertPrivateQueue();
	
	NSManagedObjectContext *moc = [self managedObjectContext];
	
	NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPResourceCoreDataStorageObject"
	                                          inManagedObjectContext:moc];
	
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	[fetchRequest setEntity:entity];
	[fetchRequest setFetchBatchSize:saveThreshold];
	
	if (stream)
	{
		NSPredicate *predicate;
		predicate = [NSPredicate predicateWithFormat:@"streamBareJidStr == %@",
		                                    [[self myJIDForXMPPStream:stream] bare]];
		
		[fetchRequest setPredicate:predicate];
	}
	
	NSArray *allResources = [moc executeFetchRequest:fetchRequest error:nil];
	
	NSUInteger unsavedCount = [self numberOfUnsavedChanges];
	
	for (XMPPResourceCoreDataStorageObject *resource in allResources)
	{
        XMPPUserCoreDataStorageObject *user = resource.user;
		[moc deleteObject:resource];
        [user recalculatePrimaryResource];
        
		if (++unsavedCount >= saveThreshold)
		{
			[self save];
			unsavedCount = 0;
		}
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Overrides
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)didCreateManagedObjectContext
{
	// This method is overriden from the XMPPCoreDataStore superclass.
	// From the documentation:
	// 
	// Override me, if needed, to provide customized behavior.
	// 
	// For example, you may want to perform cleanup of any non-persistent data before you start using the database.
	// 
	// The default implementation does nothing.
	
	
	// Reserved for future use (directory versioning).
	// Perhaps invoke [self _clearAllResourcesForXMPPStream:nil] ?
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Public API
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (XMPPUserCoreDataStorageObject *)myUserForXMPPStream:(XMPPStream *)stream
                                  managedObjectContext:(NSManagedObjectContext *)moc
{
	// This is a public method, so it may be invoked on any thread/queue.
	
	XMPPLogTrace();
	
	XMPPJID *myJID = stream.myJID;
	if (myJID == nil)
	{
		return nil;
	}
	
	return [self userForJID:myJID xmppStream:stream managedObjectContext:moc];
}

- (XMPPResourceCoreDataStorageObject *)myResourceForXMPPStream:(XMPPStream *)stream
                                          managedObjectContext:(NSManagedObjectContext *)moc
{
	// This is a public method, so it may be invoked on any thread/queue.
	
	XMPPLogTrace();
	
	XMPPJID *myJID = stream.myJID;
	if (myJID == nil)
	{
		return nil;
	}
	
	return [self resourceForJID:myJID xmppStream:stream managedObjectContext:moc];
}

- (XMPPUserCoreDataStorageObject *)userForJID:(XMPPJID *)jid
                                   xmppStream:(XMPPStream *)stream
                         managedObjectContext:(NSManagedObjectContext *)moc
{
	// This is a public method, so it may be invoked on any thread/queue.
	
	XMPPLogTrace();
	
	if (jid == nil) return nil;
	if (moc == nil) return nil;
	
	NSString *bareJIDStr = [jid bare];
	
	NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPUserCoreDataStorageObject"
	                                          inManagedObjectContext:moc];
	
	NSPredicate *predicate;
	if (stream == nil)
		predicate = [NSPredicate predicateWithFormat:@"jidStr == %@", bareJIDStr];
	else
		predicate = [NSPredicate predicateWithFormat:@"jidStr == %@ AND streamBareJidStr == %@",
					 bareJIDStr, [[self myJIDForXMPPStream:stream] bare]];
	
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	[fetchRequest setEntity:entity];
	[fetchRequest setPredicate:predicate];
	[fetchRequest setIncludesPendingChanges:YES];
	[fetchRequest setFetchLimit:1];
	
	NSArray *results = [moc executeFetchRequest:fetchRequest error:nil];
	
	return (XMPPUserCoreDataStorageObject *)[results lastObject];
}

- (XMPPResourceCoreDataStorageObject *)resourceForJID:(XMPPJID *)jid
										   xmppStream:(XMPPStream *)stream
                                 managedObjectContext:(NSManagedObjectContext *)moc
{
	// This is a public method, so it may be invoked on any thread/queue.
	
	XMPPLogTrace();
	
	if (jid == nil) return nil;
	if (moc == nil) return nil;
	
	NSString *fullJIDStr = [jid full];
	
	NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPResourceCoreDataStorageObject"
	                                          inManagedObjectContext:moc];
	
	NSPredicate *predicate;
	if (stream == nil)
		predicate = [NSPredicate predicateWithFormat:@"jidStr == %@", fullJIDStr];
	else
		predicate = [NSPredicate predicateWithFormat:@"jidStr == %@ AND streamBareJidStr == %@",
					 fullJIDStr, [[self myJIDForXMPPStream:stream] bare]];
	
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	[fetchRequest setEntity:entity];
	[fetchRequest setPredicate:predicate];
	[fetchRequest setIncludesPendingChanges:YES];
	[fetchRequest setFetchLimit:1];
	
	NSArray *results = [moc executeFetchRequest:fetchRequest error:nil];
	
	return (XMPPResourceCoreDataStorageObject *)[results lastObject];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Protocol Private API
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)beginRosterPopulationForXMPPStream:(XMPPStream *)stream withVersion:(NSString *)version
{
	XMPPLogTrace();
	
	[self scheduleBlock:^{
		
		[rosterPopulationSet addObject:[NSNumber xmpp_numberWithPtr:(__bridge void *)stream]];
    
		// Clear anything already in the roster core data store.
		// 
		// Note: Deleting a user will delete all associated resources
		// because of the cascade rule in our core data model.
		
		NSManagedObjectContext *moc = [self managedObjectContext];
		
		NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPUserCoreDataStorageObject"
		                                          inManagedObjectContext:moc];
		
		NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
		[fetchRequest setEntity:entity];
		[fetchRequest setFetchBatchSize:saveThreshold];
		
		if (stream)
		{
			NSPredicate *predicate;
			predicate = [NSPredicate predicateWithFormat:@"streamBareJidStr == %@",
			                                     [[self myJIDForXMPPStream:stream] bare]];
			
			[fetchRequest setPredicate:predicate];
		}
		
		NSArray *allUsers = [moc executeFetchRequest:fetchRequest error:nil];
		
		for (XMPPUserCoreDataStorageObject *user in allUsers)
		{
			[moc deleteObject:user];
		}
		
		[XMPPGroupCoreDataStorageObject clearEmptyGroupsInManagedObjectContext:moc];
	}];
}

- (void)endRosterPopulationForXMPPStream:(XMPPStream *)stream
{
	XMPPLogTrace();
	
	[self scheduleBlock:^{
		
		[rosterPopulationSet removeObject:[NSNumber xmpp_numberWithPtr:(__bridge void *)stream]];
	}];
}

- (void)handleRosterItem:(NSXMLElement *)itemSubElement xmppStream:(XMPPStream *)stream
{
	XMPPLogTrace();
	
	// Remember XML heirarchy memory management rules.
	// The passed parameter is a subnode of the IQ, and we need to pass it to an asynchronous operation.
	NSXMLElement *item = [itemSubElement copy];
	
	[self scheduleBlock:^{
		
		NSManagedObjectContext *moc = [self managedObjectContext];
		
		if ([rosterPopulationSet containsObject:[NSNumber xmpp_numberWithPtr:(__bridge void *)stream]])
		{
			NSString *streamBareJidStr = [[self myJIDForXMPPStream:stream] bare];
			
			[XMPPUserCoreDataStorageObject insertInManagedObjectContext:moc
			                                                   withItem:item
			                                           streamBareJidStr:streamBareJidStr];
		}
		else
		{
			NSString *jidStr = [item attributeStringValueForName:@"jid"];
			XMPPJID *jid = [[XMPPJID jidWithString:jidStr] bareJID];
			
			XMPPUserCoreDataStorageObject *user = [self userForJID:jid xmppStream:stream managedObjectContext:moc];
			
			NSString *subscription = [item attributeStringValueForName:@"subscription"];
			if ([subscription isEqualToString:@"remove"])
			{
				if (user)
				{
					[moc deleteObject:user];
				}
			}
			else
			{
				if (user)
				{
					[user updateWithItem:item];
				}
				else
				{
					NSString *streamBareJidStr = [[self myJIDForXMPPStream:stream] bare];
					
					[XMPPUserCoreDataStorageObject insertInManagedObjectContext:moc
					                                                   withItem:item
					                                           streamBareJidStr:streamBareJidStr];
				}
			}
		}
	}];
}

- (void)handlePresence:(XMPPPresence *)presence xmppStream:(XMPPStream *)stream
{
	XMPPLogTrace();
    
    BOOL allowRosterlessOperation = [parent allowRosterlessOperation];
	
	[self scheduleBlock:^{
		
		XMPPJID *jid = [presence from];
		NSManagedObjectContext *moc = [self managedObjectContext];
		
		NSString *streamBareJidStr = [[self myJIDForXMPPStream:stream] bare];
		
		XMPPUserCoreDataStorageObject *user = [self userForJID:jid xmppStream:stream managedObjectContext:moc];
		
		if (user == nil && allowRosterlessOperation)
		{
			// This may happen if the roster is in rosterlessOperation mode.
			
			user = [XMPPUserCoreDataStorageObject insertInManagedObjectContext:moc
			                                                           withJID:[presence from]
			                                                  streamBareJidStr:streamBareJidStr];
		}
		
		[user updateWithPresence:presence streamBareJidStr:streamBareJidStr];
	}];
}

- (BOOL)userExistsWithJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream
{
	XMPPLogTrace();
	
	__block BOOL result = NO;
	
	[self executeBlock:^{
		
		NSManagedObjectContext *moc = [self managedObjectContext];
		XMPPUserCoreDataStorageObject *user = [self userForJID:jid xmppStream:stream managedObjectContext:moc];
		
		result = (user != nil);
	}];
	
	return result;
}

#if TARGET_OS_IPHONE
- (void)setPhoto:(UIImage *)photo forUserWithJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream
#else
- (void)setPhoto:(NSImage *)photo forUserWithJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream
#endif
{
	XMPPLogTrace();
	
	[self scheduleBlock:^{
		
		NSManagedObjectContext *moc = [self managedObjectContext];
		XMPPUserCoreDataStorageObject *user = [self userForJID:jid xmppStream:stream managedObjectContext:moc];
		
		if (user)
		{
			user.photo = photo;
		}
	}];
}

- (void)clearAllResourcesForXMPPStream:(XMPPStream *)stream
{
	XMPPLogTrace();
	
	[self scheduleBlock:^{
		
		[self _clearAllResourcesForXMPPStream:stream];
	}];
}

- (void)clearAllUsersAndResourcesForXMPPStream:(XMPPStream *)stream
{
	XMPPLogTrace();
	
	[self scheduleBlock:^{
		
		// Note: Deleting a user will delete all associated resources
		// because of the cascade rule in our core data model.
		
		NSManagedObjectContext *moc = [self managedObjectContext];
		
		NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPUserCoreDataStorageObject"
												  inManagedObjectContext:moc];
		
		NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
		[fetchRequest setEntity:entity];
		[fetchRequest setFetchBatchSize:saveThreshold];
		
		if (stream)
		{
			NSPredicate *predicate;
			predicate = [NSPredicate predicateWithFormat:@"streamBareJidStr == %@",
			                            [[self myJIDForXMPPStream:stream] bare]];
			
			[fetchRequest setPredicate:predicate];
		}
		
		NSArray *allUsers = [moc executeFetchRequest:fetchRequest error:nil];
		
		NSUInteger unsavedCount = [self numberOfUnsavedChanges];
		
		for (XMPPUserCoreDataStorageObject *user in allUsers)
		{
			[moc deleteObject:user];
			
			if (++unsavedCount >= saveThreshold)
			{
				[self save];
				unsavedCount = 0;
			}
		}
    
		[XMPPGroupCoreDataStorageObject clearEmptyGroupsInManagedObjectContext:moc];
	}];
}

- (NSArray *)jidsForXMPPStream:(XMPPStream *)stream{
    
    XMPPLogTrace();
    
    __block NSMutableArray *results = [NSMutableArray array];
	
	[self executeBlock:^{
		
		NSManagedObjectContext *moc = [self managedObjectContext];
		
		NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPUserCoreDataStorageObject"
												  inManagedObjectContext:moc];
		
		NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
		[fetchRequest setEntity:entity];
		[fetchRequest setFetchBatchSize:saveThreshold];
		
		if (stream)
		{
			NSPredicate *predicate;
			predicate = [NSPredicate predicateWithFormat:@"streamBareJidStr == %@",
                         [[self myJIDForXMPPStream:stream] bare]];
			
			[fetchRequest setPredicate:predicate];
		}
		
		NSArray *allUsers = [moc executeFetchRequest:fetchRequest error:nil];
        
        for(XMPPUserCoreDataStorageObject *user in allUsers){
            [results addObject:[user.jid bareJID]];
        }
		
	}];
    
    return results;
}

- (void)getSubscription:(NSString * _Nullable __autoreleasing * _Nullable)subscription
                    ask:(NSString * _Nullable __autoreleasing * _Nullable)ask
               nickname:(NSString * _Nullable __autoreleasing * _Nullable)nickname
                 groups:(NSArray<NSString*> * _Nullable __autoreleasing * _Nullable)groups
                 forJID:(XMPPJID *)jid
             xmppStream:(XMPPStream *)stream
{
    XMPPLogTrace();
        
    [self executeBlock:^{
        
        NSManagedObjectContext *moc = [self managedObjectContext];
        XMPPUserCoreDataStorageObject *user = [self userForJID:jid xmppStream:stream managedObjectContext:moc];
        
        if(user)
        {
            if(subscription)
            {
                *subscription = user.subscription;
            }
            
            if(ask)
            {
                *ask = user.ask;
            }
            
            if(nickname)
            {
                *nickname = user.nickname;
            }
            
            if(groups)
            {
                if([user.groups count])
                {
                    NSMutableArray *groupNames = [NSMutableArray array];
                    
                    for(XMPPGroupCoreDataStorageObject *group in user.groups){
                        [groupNames addObject:group.name];
                    }
                    
                    *groups = groupNames;
                }
            }
        }
    }];
}

@end
