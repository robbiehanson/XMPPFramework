//
//  XMPPStreamCoreDataStorage.h
//
//  Created by Eric Chamberlain on 9/29/10.
//  Copyright 2010 RF.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class XMPPStream;
@class XMPPUserCoreDataStorage;

@interface XMPPStreamCoreDataStorage : NSManagedObject {

}

@property (nonatomic, retain) NSString * myJIDStr;
@property (nonatomic, retain) NSSet* users;

+ (id)getOrInsertInManagedObjectContext:(NSManagedObjectContext *)moc
                         withXMPPStream:(XMPPStream *)xmppStream;

+ (id)insertInManagedObjectContext:(NSManagedObjectContext *)moc withStream:(XMPPStream *)stream;

@end

// coalesce these into one @interface XMPPStreamCoreDataStorage (CoreDataGeneratedAccessors) section
@interface XMPPStreamCoreDataStorage (CoreDataGeneratedAccessors)
- (void)addUsersObject:(XMPPUserCoreDataStorage *)value;
- (void)removeUsersObject:(XMPPUserCoreDataStorage *)value;
- (void)addUsers:(NSSet *)value;
- (void)removeUsers:(NSSet *)value;

@end
