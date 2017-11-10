#import "NSManagedObject+XMPPCoreDataStorage.h"

@implementation NSManagedObject (XMPPCoreDataStorage)

+ (instancetype)xmpp_insertNewObjectInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    return [[self alloc] initWithEntity:[self xmpp_entityInManagedObjectContext:managedObjectContext]
         insertIntoManagedObjectContext:managedObjectContext];
}

+ (NSFetchRequest *)xmpp_fetchRequestInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    fetchRequest.entity = [self xmpp_entityInManagedObjectContext:managedObjectContext];
    return fetchRequest;
}

+ (NSPredicate *)xmpp_jidPredicateWithDomainKeyPath:(NSString *)domainKeyPath resourceKeyPath:(NSString *)resourceKeyPath userKeyPath:(NSString *)userKeyPath value:(XMPPJID *)value compareOptions:(XMPPJIDCompareOptions)compareOptions
{
    NSMutableArray *subpredicates = [[NSMutableArray alloc] init];
    
    if (compareOptions & XMPPJIDCompareDomain) {
        [subpredicates addObject:[NSPredicate predicateWithFormat:@"%K = %@", domainKeyPath, value.domain]];
    }
    
    if (compareOptions & XMPPJIDCompareResource) {
        [subpredicates addObject:[NSPredicate predicateWithFormat:@"%K = %@", resourceKeyPath, value.resource]];
    }
    
    if (compareOptions & XMPPJIDCompareUser) {
        [subpredicates addObject:[NSPredicate predicateWithFormat:@"%K = %@", userKeyPath, value.user]];
    }
    
    return [NSCompoundPredicate andPredicateWithSubpredicates:subpredicates];
}

+ (NSEntityDescription *)xmpp_entityInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    NSUInteger selfEntityIndex = [managedObjectContext.persistentStoreCoordinator.managedObjectModel.entities indexOfObjectPassingTest:^BOOL(NSEntityDescription * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        BOOL matchesSelf = [obj.managedObjectClassName isEqualToString:NSStringFromClass(self)];
        if (matchesSelf) {
            *stop = YES;
        }
        return matchesSelf;
    }];
    NSAssert(selfEntityIndex != NSNotFound, @"Entity for %@ not found", self);
    
    return managedObjectContext.persistentStoreCoordinator.managedObjectModel.entities[selfEntityIndex];
}

@end

@implementation NSManagedObjectContext (XMPPCoreDataStorage)

- (NSArray *)xmpp_executeForcedSuccessFetchRequest:(NSFetchRequest *)fetchRequest
{
    NSError *error;
    NSArray *fetchResult = [self executeFetchRequest:fetchRequest error:&error];
    if (!fetchResult) {
        NSAssert(NO, @"Fetch request %@ failed with error %@", fetchRequest, error);
    }
    return fetchResult;
}

@end
