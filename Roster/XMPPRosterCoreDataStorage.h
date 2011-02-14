#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "XMPPRoster.h"

@class XMPPStream;

/**
 * This class is an example implementation of XMPPRosterStorage using core data.
 * You are free to substitute your own roster storage class.
**/

@interface XMPPRosterCoreDataStorage : NSObject <XMPPRosterStorage>
{	
	NSManagedObjectModel *managedObjectModel;
	NSPersistentStoreCoordinator *persistentStoreCoordinator;
	NSManagedObjectContext *managedObjectContext;
    NSMutableDictionary *rosterPopulation;
}

@property (nonatomic, readonly) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (nonatomic, readonly) NSManagedObjectContext *managedObjectContext;
@property (retain) NSMutableDictionary *rosterPopulation;

/*
 * add the XMPPStream to core data.
 * used to track multiple XMPPStreams.
*/
- (void)addXMPPStream:(XMPPStream *)xmppStream;

@end

