//
//  XMPPvCardCoreDataStorage.m
//  XEP-0054 vCard-temp
//
//  Originally created by Eric Chamberlain on 3/18/11.
//

#import "XMPPvCardCoreDataStorage.h"
#import "XMPPvCardCoreDataStorageObject.h"
#import "XMPPvCardTempCoreDataStorageObject.h"
#import "XMPPvCardAvatarCoreDataStorageObject.h"
#import "XMPP.h"
#import "XMPPCoreDataStorageProtected.h"
#import "XMPPLogging.h"

// Log levels: off, error, warn, info, verbose
static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN; // | XMPP_LOG_FLAG_TRACE;


enum {
  kXMPPvCardTempNetworkFetchTimeout = 10,
};


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPvCardCoreDataStorage

static XMPPvCardCoreDataStorage *sharedInstance;

+ (XMPPvCardCoreDataStorage *)sharedInstance
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		
		sharedInstance = [[XMPPvCardCoreDataStorage alloc] initWithDatabaseFilename:nil];
	});
	
	return sharedInstance;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Setup
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)configureWithParent:(XMPPvCardTempModule *)aParent queue:(dispatch_queue_t)queue
{
	return [super configureWithParent:aParent queue:queue];
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPvCardAvatarStorage protocol
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSData *)photoDataForJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream
{
  // This is a public method.
	// It may be invoked on any thread/queue.
	
	XMPPLogTrace();
	
	if (storageQueue == NULL)
	{
		XMPPLogWarn(@"%@: Method(%@) invoked before storage configured by parent.", THIS_FILE, THIS_METHOD);
		return nil;
	}
	
	__block NSData *result;
	
	dispatch_block_t block = ^{
		
		XMPPvCardCoreDataStorageObject *vCard;
		vCard = [XMPPvCardCoreDataStorageObject fetchOrInsertvCardForJID:jid
		                                          inManagedObjectContext:[self managedObjectContext]];
		
		result = vCard.photoData;
	};
	
	if (dispatch_get_current_queue() == storageQueue)
	{
		block();
		return result;
	}
	else
	{
		dispatch_sync(storageQueue, ^{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			
			block();
			[result retain];
			
			[pool drain];
		});
		
		return [result autorelease];
	}
}

- (NSString *)photoHashForJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream 
{
  // This is a public method.
	// It may be invoked on any thread/queue.
	
	XMPPLogTrace();
	
	if (storageQueue == NULL)
	{
		XMPPLogWarn(@"%@: Method(%@) invoked before storage configured by parent.", THIS_FILE, THIS_METHOD);
		return nil;
	}
	
	__block NSString *result;
	
	dispatch_block_t block = ^{
		
		XMPPvCardCoreDataStorageObject *vCard;
		vCard = [XMPPvCardCoreDataStorageObject fetchOrInsertvCardForJID:jid
		                                          inManagedObjectContext:[self managedObjectContext]];
		
		result = vCard.photoHash;
	};
	
	if (dispatch_get_current_queue() == storageQueue)
	{
		block();
		return result;
	}
	else
	{
		dispatch_sync(storageQueue, ^{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			
			block();
			[result retain];
			
			[pool drain];
		});
		
		return [result autorelease];
	}
}

- (void)clearvCardTempForJID:(XMPPJID *)jid  xmppStream:(XMPPStream *)stream
{
  // This is a public method.
	// It may be invoked on any thread/queue.
	
	XMPPLogTrace();
	
	if (storageQueue == NULL)
	{
		XMPPLogWarn(@"%@: Method(%@) invoked before storage configured by parent.", THIS_FILE, THIS_METHOD);
		return;
	}
	
	dispatch_block_t block = ^{
		
		XMPPvCardCoreDataStorageObject *vCard;
		vCard = [XMPPvCardCoreDataStorageObject fetchOrInsertvCardForJID:jid
		                                          inManagedObjectContext:[self managedObjectContext]];
		
    vCard.vCardTemp = nil;
    vCard.lastUpdated = [NSDate date];
		
		[self save];
	};
	
	
	if (dispatch_get_current_queue() == storageQueue)
	{
		block();
	}
	else
	{
		dispatch_sync(storageQueue, ^{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			
			block();
			
			[pool drain];
		});
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPvCardTempModuleStorage protocol
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (XMPPvCardTemp *)vCardTempForJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream
{
	// This is a public method.
	// It may be invoked on any thread/queue.
	
	XMPPLogTrace();
	
	if (storageQueue == NULL)
	{
		XMPPLogWarn(@"%@: Method(%@) invoked before storage configured by parent.", THIS_FILE, THIS_METHOD);
		return nil;
	}
	
	__block XMPPvCardTemp *result;
	
	dispatch_block_t block = ^{
		
		XMPPvCardCoreDataStorageObject *vCard;
		vCard = [XMPPvCardCoreDataStorageObject fetchOrInsertvCardForJID:jid
		                                          inManagedObjectContext:[self managedObjectContext]];
		
		result = vCard.vCardTemp;
	};
	
	if (dispatch_get_current_queue() == storageQueue)
	{
		block();
		return result;
	}
	else
	{
		dispatch_sync(storageQueue, ^{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			
			block();
			[result retain];
			
			[pool drain];
		});
		
		return [result autorelease];
	}
}

- (void)setvCardTemp:(XMPPvCardTemp *)vCardTemp forJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream
{
	// This is a public method.
	// It may be invoked on any thread/queue.
	
	XMPPLogTrace();
	
	if (storageQueue == NULL)
	{
		XMPPLogWarn(@"%@: Method(%@) invoked before storage configured by parent.", THIS_FILE, THIS_METHOD);
		return;
	}
	
	dispatch_block_t block = ^{
		
		XMPPvCardCoreDataStorageObject *vCard;
		vCard = [XMPPvCardCoreDataStorageObject fetchOrInsertvCardForJID:jid
		                                          inManagedObjectContext:[self managedObjectContext]];
		
		vCard.waitingForFetch = [NSNumber numberWithBool:NO];
		vCard.vCardTemp = vCardTemp;
		
		// Update photo and photo hash
		vCard.photoData = vCardTemp.photo;
		
		vCard.lastUpdated = [NSDate date];
		
		[self save];
	};
	
	
	if (dispatch_get_current_queue() == storageQueue)
	{
		block();
	}
	else
	{
		dispatch_sync(storageQueue, ^{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			
			block();
			
			[pool drain];
		});
	}
}

- (BOOL)shouldFetchvCardTempForJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream
{
	// This is a public method.
	// It may be invoked on any thread/queue.
	
	XMPPLogTrace();
	
	if (storageQueue == NULL)
	{
		XMPPLogWarn(@"%@: Method(%@) invoked before storage configured by parent.", THIS_FILE, THIS_METHOD);
		return YES;
	}
	
	__block BOOL result;
	
	dispatch_block_t block = ^{
		
		XMPPvCardCoreDataStorageObject *vCard;
		vCard = [XMPPvCardCoreDataStorageObject fetchOrInsertvCardForJID:jid
		                                          inManagedObjectContext:[self managedObjectContext]];
		
		BOOL waitingForFetch = [vCard.waitingForFetch boolValue];
		
		if (!waitingForFetch)
		{
			vCard.waitingForFetch = [NSNumber numberWithBool:YES];
			vCard.lastUpdated = [NSDate date];
			
			[self save];
			result = YES;
		}
		else if ([vCard.lastUpdated timeIntervalSinceNow] < -kXMPPvCardTempNetworkFetchTimeout)
		{
			// Our last request exceeded the timeout, send a new one
			vCard.lastUpdated = [NSDate date];
			
			[self save];
			result = YES;
		}
		else
		{
			// We already have an outstanding request, no need to send another one.
			result = NO;
		}
	};
	
	
	if (dispatch_get_current_queue() == storageQueue)
	{
		block();
	}
	else
	{
		dispatch_sync(storageQueue, ^{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			
			block();
			
			[pool drain];
		});
	}
	
	return result;
}

@end
