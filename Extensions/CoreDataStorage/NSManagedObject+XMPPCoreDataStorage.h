#import <CoreData/CoreData.h>
#import "XMPPJID.h"

@interface NSManagedObject (XMPPCoreDataStorage)

/// @brief Inserts a managed object with an entity whose name matches the class name.
/// @discussion An assertion will be triggered if no matching entity is found in the model.
+ (instancetype)xmpp_insertNewObjectInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

/// @brief Returns a fetch request for an entity whose name matches the class name.
/// @discussion An assertion will be triggered if no matching entity is found in the model.
+ (NSFetchRequest *)xmpp_fetchRequestInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

/// @brief Returns a predicate for filtering managed objects on JID component attributes.
/// @discussion The provided keypaths are relative to the fetched entity and the filtering logic follows @c [XMPPJID @c isEqualToJID:options:] implementation.
+ (NSPredicate *)xmpp_jidPredicateWithDomainKeyPath:(NSString *)domainKeyPath
                                    resourceKeyPath:(NSString *)resourceKeyPath
                                        userKeyPath:(NSString *)userKeyPath
                                              value:(XMPPJID *)value
                                     compareOptions:(XMPPJIDCompareOptions)compareOptions;

@end

@interface NSManagedObjectContext (XMPPCoreDataStorage)

/// Executes the provided fetch request raising an assertion upon failure.
- (NSArray *)xmpp_executeForcedSuccessFetchRequest:(NSFetchRequest *)fetchRequest;

@end
