//
//  XMPPvCardCoreDataStorageController.m
//  XEP-0054 vCard-temp
//
//  Created by Eric Chamberlain on 3/18/11.
//  Copyright 2011 RF.com. All rights reserved.
//

#import "XMPPvCardCoreDataStorageController.h"

#ifndef DEBUG_LEVEL
#define DEBUG_LEVEL 4
#endif

#import "DDLog.h"
#import "NSDataAdditions.h"
#import "SynthesizeSingleton.h"
#import "XMPPvCardAvatarCoreDataStorage.h"
#import "XMPPvCardCoreDataStorage.h"
#import "XMPPvCardTempCoreDataStorage.h"


enum {
  kXMPPvCardTempNetworkFetchTimeout = 10,
};


@interface XMPPvCardCoreDataStorageController()

- (NSString *)persistentStoreDirectory;

- (void)save;


@end


@implementation XMPPvCardCoreDataStorageController


#pragma mark - Init/dealloc methods


SYNTHESIZE_SINGLETON_FOR_CLASS(XMPPvCardCoreDataStorageController);


- (void)dealloc {
  [_managedObjectContext release];
  [_managedObjectModel release];
  [_persistentStoreCoordinator release];
  
  [super dealloc];
}


#pragma mark - XMPPvCardAvatarStorage protocol


- (NSString *)photoHashForJID:(XMPPJID *)jid {
  XMPPvCardCoreDataStorage *vCard = [XMPPvCardCoreDataStorage fetchOrInsertvCardForJID:jid 
                                                                inManagedObjectContext:self.managedObjectContext];
  return vCard.photoHash;
}


- (void)clearvCardTempForJID:(XMPPJID *)jid {
  XMPPvCardCoreDataStorage *vCard = [XMPPvCardCoreDataStorage fetchOrInsertvCardForJID:jid 
                                                                inManagedObjectContext:self.managedObjectContext];
  vCard.vCardTemp = nil;
  vCard.lastUpdated = [NSDate date];
  [self save];
}


#pragma mark - XMPPvCardTempModuleStorage protocol


- (XMPPvCardTemp *)vCardTempForJID:(XMPPJID *)jid {
	XMPPvCardCoreDataStorage *vCard = [XMPPvCardCoreDataStorage fetchOrInsertvCardForJID:jid 
                                                                inManagedObjectContext:self.managedObjectContext];
  
	return vCard.vCardTemp;
}


- (void)setvCardTemp:(XMPPvCardTemp *)vCardTemp forJID:(XMPPJID *)jid {
  XMPPvCardCoreDataStorage *vCard = [XMPPvCardCoreDataStorage fetchOrInsertvCardForJID:jid 
                                                                inManagedObjectContext:self.managedObjectContext];
  vCard.waitingForFetch = [NSNumber numberWithBool:NO];
  vCard.vCardTemp = vCardTemp;
  
  // update photo and photo hash
  vCard.photoData = vCardTemp.photo;
   
  vCard.lastUpdated = [NSDate date];
  
  [self save];
}


- (BOOL)shouldFetchvCardTempForJID:(XMPPJID *)jid {
  XMPPvCardCoreDataStorage *vCard = [XMPPvCardCoreDataStorage fetchOrInsertvCardForJID:jid 
                                                                inManagedObjectContext:self.managedObjectContext];
  BOOL result = YES;
  BOOL waitingForFetch = [vCard.waitingForFetch boolValue];
  
  if (!waitingForFetch) {
    vCard.waitingForFetch = [NSNumber numberWithBool:YES];
    vCard.lastUpdated = [NSDate date];
    
    [self save];
  } else if ([vCard.lastUpdated timeIntervalSinceNow] < -kXMPPvCardTempNetworkFetchTimeout) {
    // our last request exceeded the timeout, send a new one
    vCard.lastUpdated = [NSDate date];
    
    [self save];
  } else {
    // we already have an outstanding request, no need to send another one.
    result = NO;
  }
  return result;
}


#pragma mark - Private methods


- (NSString *)persistentStoreDirectory
{
#if TARGET_OS_IPHONE
	
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSString *result = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
	
#else
	
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
  NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : NSTemporaryDirectory();
	
	NSString *result = [basePath stringByAppendingPathComponent:@"XMPPStream"];
	
#endif
	
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	if(![fileManager fileExistsAtPath:result])
	{
		[fileManager createDirectoryAtPath:result withIntermediateDirectories:YES attributes:nil error:nil];
	}
	
  return result;
}


- (void)save {
  NSError *error = nil;
  if ([self.managedObjectContext hasChanges] && 
      ![self.managedObjectContext save:&error]) {
    DDLogError(@"%s error: %@",__PRETTY_FUNCTION__, error);
  }
}


#pragma mark - Getter/setter methods


@synthesize managedObjectContext = _managedObjectContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Core Data Setup
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


- (NSManagedObjectContext *)managedObjectContext
{
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


- (NSManagedObjectModel *)managedObjectModel
{
	if (_managedObjectModel != nil)
	{
		return _managedObjectModel;
	}
	
	NSString *path = [[NSBundle mainBundle] pathForResource:@"XMPPvCard" ofType:@"momd"];
	if (path)
	{
		// If path is nil, then NSURL or NSManagedObjectModel will throw an exception
		
		NSURL *url = [NSURL fileURLWithPath:path];
		
		_managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:url];
	}
	
	return _managedObjectModel;
}


- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
	if (_persistentStoreCoordinator)
	{
		return _persistentStoreCoordinator;
	}
	
	NSManagedObjectModel *mom = self.managedObjectModel;
	
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
		if(!persistentStore)
		{
			NSLog(@"=====================================================================================");
			NSLog(@"Error creating persistent store:\n%@", error);
#if TARGET_OS_IPHONE
			NSLog(@"Chaned core data model recently? Quick Fix: Delete the app from device and reinstall.");
#else
			NSLog(@"Quick Fix: Delete the database: %@", storePath);
#endif
			NSLog(@"=====================================================================================");
		}
	}
  
  return _persistentStoreCoordinator;
}


@end
