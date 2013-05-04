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

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

// Log levels: off, error, warn, info, verbose
#if DEBUG
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN; // | XMPP_LOG_FLAG_TRACE;
#else
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

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
#pragma mark Overrides
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)commonInit
{
    autoAllowExternalBinaryDataStorage = YES;
    [super commonInit];
}
- (BOOL)addPersistentStoreWithPath:(NSString *)storePath error:(NSError **)errorPtr
{    
    BOOL result = [super addPersistentStoreWithPath:storePath error:errorPtr];
    
    if (!result &&
        [*errorPtr code] == NSMigrationMissingSourceModelError &&
        [[*errorPtr domain] isEqualToString:NSCocoaErrorDomain]) {
        // If we get this error while trying to add the persistent store, it most likely means the model changed.
        // Since we are caching capabilities, it is safe to delete the persistent store and create a new one.
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:storePath])
        {
            [[NSFileManager defaultManager] removeItemAtPath:storePath error:nil];
            
            // Try creating the store again, without creating a deletion/creation loop.
            result = [super addPersistentStoreWithPath:storePath error:errorPtr];
        }
    }
    
    return result;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPvCardAvatarStorage protocol
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSData *)photoDataForJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream
{
	// This is a public method.
	// It may be invoked on any thread/queue.
	
	XMPPLogTrace();
	
	__block NSData *result;
	
	[self executeBlock:^{
		
		XMPPvCardCoreDataStorageObject *vCard;
		vCard = [XMPPvCardCoreDataStorageObject fetchOrInsertvCardForJID:jid
		                                          inManagedObjectContext:[self managedObjectContext]];
		
		result = vCard.photoData;
	}];
	
	return result;
}

- (NSString *)photoHashForJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream 
{
	// This is a public method.
	// It may be invoked on any thread/queue.
	
	XMPPLogTrace();
	
	__block NSString *result;
	
	[self executeBlock:^{
		
		XMPPvCardCoreDataStorageObject *vCard;
		vCard = [XMPPvCardCoreDataStorageObject fetchOrInsertvCardForJID:jid
		                                          inManagedObjectContext:[self managedObjectContext]];
		
		result = vCard.photoHash;
	}];
	
	return result;
}

- (void)clearvCardTempForJID:(XMPPJID *)jid  xmppStream:(XMPPStream *)stream
{
	// This is a public method.
	// It may be invoked on any thread/queue.
	
	XMPPLogTrace();
	
	[self scheduleBlock:^{
		
		XMPPvCardCoreDataStorageObject *vCard;
		vCard = [XMPPvCardCoreDataStorageObject fetchOrInsertvCardForJID:jid
		                                          inManagedObjectContext:[self managedObjectContext]];
		
		vCard.vCardTemp = nil;
		vCard.lastUpdated = [NSDate date];
	}];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPvCardTempModuleStorage protocol
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (XMPPvCardTemp *)vCardTempForJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream
{
	// This is a public method.
	// It may be invoked on any thread/queue.
	
	XMPPLogTrace();
	
	__block XMPPvCardTemp *result;
	
	[self executeBlock:^{
		
		XMPPvCardCoreDataStorageObject *vCard;
		vCard = [XMPPvCardCoreDataStorageObject fetchOrInsertvCardForJID:jid
		                                          inManagedObjectContext:[self managedObjectContext]];
		
		result = vCard.vCardTemp;
	}];
	
	return result;
}

- (void)setvCardTemp:(XMPPvCardTemp *)vCardTemp forJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream
{
	// This is a public method.
	// It may be invoked on any thread/queue.
	
	XMPPLogTrace();
	
	[self scheduleBlock:^{
		
		XMPPvCardCoreDataStorageObject *vCard;
		vCard = [XMPPvCardCoreDataStorageObject fetchOrInsertvCardForJID:jid
		                                          inManagedObjectContext:[self managedObjectContext]];
		
		vCard.waitingForFetch = [NSNumber numberWithBool:NO];
		vCard.vCardTemp = vCardTemp;
		
		// Update photo and photo hash
		vCard.photoData = vCardTemp.photo;
		
		vCard.lastUpdated = [NSDate date];
	}];
}

- (XMPPvCardTemp *)myvCardTempForXMPPStream:(XMPPStream *)stream
{
    if(!stream) return nil;
    
    return [self vCardTempForJID:[[stream myJID] bareJID] xmppStream:stream];
}

- (BOOL)shouldFetchvCardTempForJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream
{
	// This is a public method.
	// It may be invoked on any thread/queue.
	
	XMPPLogTrace();
	
	__block BOOL result;
	
	[self executeBlock:^{
		
		XMPPvCardCoreDataStorageObject *vCard;
		vCard = [XMPPvCardCoreDataStorageObject fetchOrInsertvCardForJID:jid
		                                          inManagedObjectContext:[self managedObjectContext]];
		
		BOOL waitingForFetch = [vCard.waitingForFetch boolValue];
        
        if(![stream isAuthenticated])
        {
            result = NO;
		}
        else if (!waitingForFetch)
		{
			vCard.waitingForFetch = [NSNumber numberWithBool:YES];
			vCard.lastUpdated = [NSDate date];
			
			result = YES;
		}
		else if ([vCard.lastUpdated timeIntervalSinceNow] < -kXMPPvCardTempNetworkFetchTimeout)
		{
			// Our last request exceeded the timeout, send a new one
			vCard.lastUpdated = [NSDate date];
			
			result = YES;
		}
		else
		{
			// We already have an outstanding request, no need to send another one.
			result = NO;
		}
	}];
	
	return result;
}

@end
