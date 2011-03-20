//
//  XMPPGroupCoreDataStorage.m
//
//  Created by Eric Chamberlain on 3/20/11.
//  Copyright (c) 2011 RF.com. All rights reserved.
//

#import "XMPPGroupCoreDataStorage.h"
#import "XMPPUserCoreDataStorage.h"


@implementation XMPPGroupCoreDataStorage


#pragma mark -
#pragma mark Public class methods


+ (id)insertInManagedObjectContext:(NSManagedObjectContext *)moc withGroupName:(NSString *)groupName {
  if (groupName == nil) {
    return nil;
  }
  
  XMPPGroupCoreDataStorage *newGroup = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([XMPPGroupCoreDataStorage class])
                                                                     inManagedObjectContext:moc];
  newGroup.name = groupName;
  
	return newGroup;
}


+ (id)getOrInsertInManagedObjectContext:(NSManagedObjectContext *)moc withGroupName:(NSString *)groupName {
  if (groupName == nil) {
    return nil;
  }
  
  NSEntityDescription *entity = [NSEntityDescription entityForName:NSStringFromClass([XMPPGroupCoreDataStorage class])
	                                          inManagedObjectContext:moc];
	
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name == %@", groupName];
	
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	[fetchRequest setEntity:entity];
	[fetchRequest setPredicate:predicate];
	[fetchRequest setIncludesPendingChanges:YES];
	[fetchRequest setFetchLimit:1];
	
	NSArray *results = [moc executeFetchRequest:fetchRequest error:nil];
	
	[fetchRequest release];
  
  if ([results count] > 0) {
    return [results objectAtIndex:0];
  }
  
  return [self insertInManagedObjectContext:moc withGroupName:groupName];
}


#pragma mark - Getter/setter methods


@dynamic name;
@dynamic users;

- (void)addUsersObject:(XMPPUserCoreDataStorage *)value {    
    NSSet *changedObjects = [[NSSet alloc] initWithObjects:&value count:1];
    [self willChangeValueForKey:@"users" withSetMutation:NSKeyValueUnionSetMutation usingObjects:changedObjects];
    [[self primitiveValueForKey:@"users"] addObject:value];
    [self didChangeValueForKey:@"users" withSetMutation:NSKeyValueUnionSetMutation usingObjects:changedObjects];
    [changedObjects release];
}

- (void)removeUsersObject:(XMPPUserCoreDataStorage *)value {
    NSSet *changedObjects = [[NSSet alloc] initWithObjects:&value count:1];
    [self willChangeValueForKey:@"users" withSetMutation:NSKeyValueMinusSetMutation usingObjects:changedObjects];
    [[self primitiveValueForKey:@"users"] removeObject:value];
    [self didChangeValueForKey:@"users" withSetMutation:NSKeyValueMinusSetMutation usingObjects:changedObjects];
    [changedObjects release];
}

- (void)addUsers:(NSSet *)value {    
    [self willChangeValueForKey:@"users" withSetMutation:NSKeyValueUnionSetMutation usingObjects:value];
    [[self primitiveValueForKey:@"users"] unionSet:value];
    [self didChangeValueForKey:@"users" withSetMutation:NSKeyValueUnionSetMutation usingObjects:value];
}

- (void)removeUsers:(NSSet *)value {
    [self willChangeValueForKey:@"users" withSetMutation:NSKeyValueMinusSetMutation usingObjects:value];
    [[self primitiveValueForKey:@"users"] minusSet:value];
    [self didChangeValueForKey:@"users" withSetMutation:NSKeyValueMinusSetMutation usingObjects:value];
}


@end
