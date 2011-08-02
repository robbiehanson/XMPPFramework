//
//  XMPPGroupCoreDataStorageObject.m
//
//  Created by Eric Chamberlain on 3/20/11.
//  Copyright (c) 2011 RF.com. All rights reserved.
//

#import "XMPPGroupCoreDataStorageObject.h"
#import "XMPPUserCoreDataStorageObject.h"


@implementation XMPPGroupCoreDataStorageObject

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Public
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (void)clearEmptyGroupsInManagedObjectContext:(NSManagedObjectContext *)moc
{
  NSEntityDescription *entity = [NSEntityDescription entityForName:NSStringFromClass([self class])
	                                          inManagedObjectContext:moc];
	
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"users.@count == 0"];
	
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	[fetchRequest setEntity:entity];
	[fetchRequest setPredicate:predicate];
	[fetchRequest setIncludesPendingChanges:YES];
	
	NSArray *results = [moc executeFetchRequest:fetchRequest error:nil];
	
	[fetchRequest release];
  
  for (NSManagedObject *group in results) {
    [moc deleteObject:group];
  }
}

+ (id)insertGroupName:(NSString *)groupName inManagedObjectContext:(NSManagedObjectContext *)moc
{
  if (groupName == nil) {
    return nil;
  }
  
  XMPPGroupCoreDataStorageObject *newGroup = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([self class])
                                                                     inManagedObjectContext:moc];
  newGroup.name = groupName;
  
	return newGroup;
}


+ (id)fetchOrInsertGroupName:(NSString *)groupName inManagedObjectContext:(NSManagedObjectContext *)moc {
  if (groupName == nil) {
    return nil;
  }
  
  NSEntityDescription *entity = [NSEntityDescription entityForName:NSStringFromClass([self class])
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
  
  return [self insertGroupName:groupName inManagedObjectContext:moc];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Accessors
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@dynamic name;
@dynamic users;

- (void)addUsersObject:(XMPPUserCoreDataStorageObject *)value {    
  NSSet *changedObjects = [[NSSet alloc] initWithObjects:&value count:1];
  [self willChangeValueForKey:@"users" withSetMutation:NSKeyValueUnionSetMutation usingObjects:changedObjects];
  [[self primitiveValueForKey:@"users"] addObject:value];
  [self didChangeValueForKey:@"users" withSetMutation:NSKeyValueUnionSetMutation usingObjects:changedObjects];
  [changedObjects release];
}

- (void)removeUsersObject:(XMPPUserCoreDataStorageObject *)value {
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
