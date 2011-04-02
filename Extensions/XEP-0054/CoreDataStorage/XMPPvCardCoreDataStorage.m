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
#import "XMPPLogging.h"
#import "NSDataAdditions.h"

#import <objc/runtime.h>

// Log levels: off, error, warn, info, verbose
// Log flags: trace
static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN; // | XMPP_LOG_FLAG_TRACE;

enum {
  kXMPPvCardTempNetworkFetchTimeout = 10,
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPvCardCoreDataStorage

- (id)init
{
	return [self initForSingleUsage];
}

- (id)initForSingleUsage
{
	if ((self = [super init]))
	{
		singleUsage = YES;
	}
	return self;
}

- (id)initForMultipleUsage
{
	return [self initForMultipleUsageWithDispatchQueue:NULL];
}

- (id)initForMultipleUsageWithDispatchQueue:(dispatch_queue_t)queue
{
	if ((self = [super init]))
	{
		singleUsage = NO;
		
		if (queue)
		{
			storageQueue = queue;
			dispatch_retain(storageQueue);
		}
		else
		{
			storageQueue = dispatch_queue_create(class_getName([self class]), NULL);
		}
	}
	return self;
}

- (BOOL)configureWithParent:(XMPPvCardTempModule *)aParent queue:(dispatch_queue_t)queue
{
	NSParameterAssert(aParent != nil);
	NSParameterAssert(queue != NULL);
	
	if (singleUsage)
	{
		BOOL result = NO;
		
		@synchronized(self)
		{
			if (storageQueue == NULL)
			{
				storageQueue = queue;
				dispatch_retain(storageQueue);
				
				result = YES;
			}
		}
		
		return result;
	}
	else
	{
		return YES;
	}
}

- (void)dealloc
{
	if (storageQueue)
		dispatch_release(storageQueue);
	
	[_managedObjectContext release];
	[_persistentStoreCoordinator release];
	[_managedObjectModel release];
	
	[super dealloc];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Core Data Setup
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSString *)persistentStoreDirectory
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
	NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
	
	// Attempt to find a name for this application
	NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
	if (appName == nil) {
		appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];	
	}
	
	if (appName == nil) {
		appName = @"xmppframework";
	}
	
	
	NSString *result = [basePath stringByAppendingPathComponent:appName];
	
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	if(![fileManager fileExistsAtPath:result])
	{
		[fileManager createDirectoryAtPath:result withIntermediateDirectories:YES attributes:nil error:nil];
	}
	
	return result;
}

- (NSManagedObjectModel *)managedObjectModel
{
	// This is a public method.
	// It may be invoked on any thread/queue.
	
	if (storageQueue == NULL)
	{
		XMPPLogWarn(@"%@: Method(%@) invoked before storage configured by parent.", THIS_FILE, THIS_METHOD);
		return nil;
	}
	
	dispatch_block_t block = ^{
		
		if (_managedObjectModel)
		{
			return;
		}
		
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		XMPPLogVerbose(@"%@: Creating managedObjectModel", THIS_FILE);
		
		NSString *path = [[NSBundle mainBundle] pathForResource:@"XMPPvCard" ofType:@"momd"];
		if (path)
		{
			// If path is nil, then NSURL or NSManagedObjectModel will throw an exception
			
			NSURL *url = [NSURL fileURLWithPath:path];
			
			_managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:url];
		}
		
		[pool drain];
	};
	
	if (dispatch_get_current_queue() == storageQueue)
		block();
	else
		dispatch_sync(storageQueue, block);
	
	return _managedObjectModel;
}


- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
	// This is a public method.
	// It may be invoked on any thread/queue.
	
	if (storageQueue == NULL)
	{
		XMPPLogWarn(@"%@: Method(%@) invoked before storage configured by parent.", THIS_FILE, THIS_METHOD);
		return nil;
	}
	
	dispatch_block_t block = ^{
		
		if (_persistentStoreCoordinator)
		{
			return;
		}
		
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		NSManagedObjectModel *mom = [self managedObjectModel];
		
		XMPPLogVerbose(@"%@: Creating persistentStoreCoordinator", THIS_FILE);
		
		_persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mom];
		
		NSString *docsPath = [self persistentStoreDirectory];
		NSString *storePath = [docsPath stringByAppendingPathComponent:@"XMPPvCard.sqlite"];
		if (storePath)
		{
			if ([[NSFileManager defaultManager] fileExistsAtPath:storePath])
			{
				[[NSFileManager defaultManager] removeItemAtPath:storePath error:nil];
			}
			
			// If storePath is nil, then NSURL will throw an exception
			
			NSURL *storeUrl = [NSURL fileURLWithPath:storePath];
			
			NSError *error = nil;
			NSPersistentStore *persistentStore;
			persistentStore = [_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
			                                                            configuration:nil
			                                                                      URL:storeUrl
			                                                                  options:nil
			                                                                    error:&error];
			if (!persistentStore)
			{
			  #if TARGET_OS_IPHONE
				XMPPLogError(@"%@:\n"
				             @"=====================================================================================\n"
				             @"Error creating persistent store:\n%@\n"
				             @"Chaned core data model recently?\n"
				             @"Quick Fix: Delete the app from device and reinstall.\n"
				             @"=====================================================================================",
				             THIS_FILE, error);
			  #else
				XMPPLogError(@"%@:\n"
				             @"=====================================================================================\n"
				             @"Error creating persistent store:\n%@\n"
				             @"Chaned core data model recently?\n"
				             @"Quick Fix: Delete the database: %@\n"
				             @"=====================================================================================",
				             THIS_FILE, error, storePath);
			  #endif
			}
		}
		
		[pool drain];
	};
	
	if (dispatch_get_current_queue() == storageQueue)
		block();
	else
		dispatch_sync(storageQueue, block);
	
	return _persistentStoreCoordinator;
}

- (NSManagedObjectContext *)managedObjectContext
{
	// This is a private method.
	
	NSAssert(dispatch_get_current_queue() == storageQueue, @"Invoked on incorrect queue");
	
	if (_managedObjectContext != nil)
	{
		return _managedObjectContext;
	}
	
	NSPersistentStoreCoordinator *coordinator = self.persistentStoreCoordinator;
	if (coordinator != nil)
	{
		_managedObjectContext = [[NSManagedObjectContext alloc] init];
		[_managedObjectContext setPersistentStoreCoordinator:coordinator];
	}
	
	return _managedObjectContext;
}

- (void)save
{
	NSAssert(dispatch_get_current_queue() == storageQueue, @"Invoked on incorrect queue");
	
	NSManagedObjectContext *managedObjectContext = [self managedObjectContext];
	
	if ([managedObjectContext hasChanges])
	{
		NSError *error = nil;
		if (![managedObjectContext save:&error])
		{
			XMPPLogError(@"%@: %s error: %@", THIS_FILE, __PRETTY_FUNCTION__, error);
		}
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
		                                                      xmppStream:stream
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
		                                                      xmppStream:stream
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
		                                                      xmppStream:stream
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
