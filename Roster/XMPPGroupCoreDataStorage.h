//
//  XMPPGroupCoreDataStorage.h
//
//  Created by Eric Chamberlain on 3/20/11.
//  Copyright (c) 2011 RF.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@class XMPPUserCoreDataStorage;


@interface XMPPGroupCoreDataStorage : NSManagedObject {
@private
}


@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSSet* users;


+ (id)getOrInsertInManagedObjectContext:(NSManagedObjectContext *)moc withGroupName:(NSString *)groupName;

+ (id)insertInManagedObjectContext:(NSManagedObjectContext *)moc withGroupName:(NSString *)groupName;


@end
