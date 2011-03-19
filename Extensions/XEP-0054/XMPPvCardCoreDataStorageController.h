//
//  XMPPvCardCoreDataStorageController.h
//  XEP-0054 vCard-temp
//
//  Created by Eric Chamberlain on 3/18/11.
//  Copyright 2011 RF.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

#import "XMPPvCardAvatarModule.h"
#import "XMPPvCardTempModule.h"


@interface XMPPvCardCoreDataStorageController : NSObject <
XMPPvCardAvatarStorage,
XMPPvCardTempModuleStorage
> {
  NSManagedObjectContext *_managedObjectContext;
  NSManagedObjectModel *_managedObjectModel;
	NSPersistentStoreCoordinator *_persistentStoreCoordinator;
   
}

@property (nonatomic, readonly) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, readonly) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;


+ (XMPPvCardCoreDataStorageController *)sharedXMPPvCardCoreDataStorageController;


@end
