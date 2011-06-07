#import <Foundation/Foundation.h>
#import "XMPPRoster.h"

@class XMPPUserMemoryStorage;

/**
 * This class is an example implementation of XMPPRosterStorage using core data.
 * You are free to substitute your own storage class.
**/

@interface XMPPRosterMemoryStorage : NSObject <XMPPRosterStorage>
{
	XMPPRoster *parent;
	dispatch_queue_t parentQueue;
	
	NSMutableDictionary *roster;
	
	BOOL isRosterPopulation;
	
	XMPPUserMemoryStorage *myUser;
}

- (id)init;
 
@property (nonatomic, readonly) XMPPRoster *parent;

// The methods below provide access to the roster data.
// If invoked from a dispatch queue other than the roster's queue,
// the methods return snapshots (copies) of the roster data.
// These snapshots provide a thread-safe version of the roster data.
// The thread-safety comes from the fact that the copied data will not be altered,
// so it can therefore be used from multiple threads/queues if needed.

- (id <XMPPUser>)myUser;
- (id <XMPPResource>)myResource;

- (id <XMPPUser>)userForJID:(XMPPJID *)jid;
- (id <XMPPResource>)resourceForJID:(XMPPJID *)jid;

- (NSArray *)sortedUsersByName;
- (NSArray *)sortedUsersByAvailabilityName;

- (NSArray *)sortedAvailableUsersByName;
- (NSArray *)sortedUnavailableUsersByName;

- (NSArray *)unsortedUsers;
- (NSArray *)unsortedAvailableUsers;
- (NSArray *)unsortedUnavailableUsers;

- (NSArray *)sortedResources:(BOOL)includeResourcesForMyUserExcludingMyself;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol XMPPRosterMemoryStorageDelegate
@optional

/**
 * The XMPPRosterStorage classes use the same delegate as their parent XMPPRoster.
**/

- (void)xmppRosterDidChange:(XMPPRosterMemoryStorage *)sender;

@end
