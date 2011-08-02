//
//  XMPPGroupCoreDataStorageObject.h
//
//  Created by Eric Chamberlain on 3/20/11.
//  Copyright (c) 2011 RF.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@class XMPPUserCoreDataStorageObject;


@interface XMPPGroupCoreDataStorageObject : NSManagedObject {
@private
}

@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSSet* users;

+ (void)clearEmptyGroupsInManagedObjectContext:(NSManagedObjectContext *)moc;

+ (id)fetchOrInsertGroupName:(NSString *)groupName inManagedObjectContext:(NSManagedObjectContext *)moc;

+ (id)insertGroupName:(NSString *)groupName inManagedObjectContext:(NSManagedObjectContext *)moc;

@end
