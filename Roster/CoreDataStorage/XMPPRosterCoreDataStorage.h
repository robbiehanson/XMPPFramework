#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

#import "XMPPRoster.h"
#import "XMPPCoreDataStorage.h"

/**
 * This class is an example implementation of XMPPRosterStorage using core data.
 * You are free to substitute your own roster storage class.
**/

@interface XMPPRosterCoreDataStorage : XMPPCoreDataStorage <XMPPRosterStorage>
{
	// Inherits protected variables from XMPPCoreDataStorage
	
	NSMutableSet *rosterPopulationSet;
}

/**
 * Convenience method to get an instance with the default database name.
 * 
 * IMPORTANT:
 * You are NOT required to use the sharedInstance.
 * 
 * If your application uses multiple xmppStreams, and you use a sharedInstance of this class,
 * then all of your streams share the same database store. You might get better performance if you create
 * multiple instances of this class instead (using different database filenames), as this way you can have
 * concurrent writes to multiple databases.
**/
+ (XMPPRosterCoreDataStorage *)sharedInstance;

// 
// This class inherits from XMPPCoreDataStorage.
// 
// Please see the XMPPCoreDataStorage header file for more information.
// 

@end
