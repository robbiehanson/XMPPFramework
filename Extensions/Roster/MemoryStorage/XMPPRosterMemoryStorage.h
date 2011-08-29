#import <Foundation/Foundation.h>
#import "XMPPRoster.h"
#import "XMPPUserMemoryStorage.h"
#import "XMPPResourceMemoryStorage.h"


/**
 * This class is an example implementation of XMPPRosterStorage using core data.
 * You are free to substitute your own storage class.
**/

@interface XMPPRosterMemoryStorage : NSObject <XMPPRosterStorage>
{
	XMPPRoster *parent;
	dispatch_queue_t parentQueue;
	
	Class userClass;
	Class resourceClass;
	
	BOOL isRosterPopulation;
	NSMutableDictionary *roster;
	
	XMPPJID *myJID;
	XMPPUserMemoryStorage *myUser;
}

- (id)init;

@property (assign, readonly) XMPPRoster *parent;

/**
 * You can optionally extend the XMPPUserMemoryStorage and XMPPResourceMemoryStorage classes.
 * Then just set the classes here, and your subclasses will automatically get used.
**/
@property (readwrite, assign) Class userClass;
@property (readwrite, assign) Class resourceClass;

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

/**
 * Catch-all change notification.
 * 
 * When the roster changes, for any of the reasons listed below, this delegate method fires.
 * This method always fires after the more precise delegate methods listed below.
**/
- (void)xmppRosterDidChange:(XMPPRosterMemoryStorage *)sender;

/**
 * Notification that the roster has received the roster from the server.
 * 
 * If parent.autoFetchRoster is YES, the roster will automatically be fetched once the user authenticates.
**/
- (void)xmppRosterDidPopulate:(XMPPRosterMemoryStorage *)sender;

/**
 * Notifications that the roster has changed.
 * 
 * This includes times when users are added or removed from our roster, or when a nickname is changed,
 * including when other resources logged in under the same user account as us make changes to our roster.
 * 
 * This does not include when resources simply go online / offline.
**/
- (void)xmppRoster:(XMPPRosterMemoryStorage *)sender didAddUser:(XMPPUserMemoryStorage *)user;
- (void)xmppRoster:(XMPPRosterMemoryStorage *)sender didUpdateUser:(XMPPUserMemoryStorage *)user;
- (void)xmppRoster:(XMPPRosterMemoryStorage *)sender didRemoveUser:(XMPPUserMemoryStorage *)user;

/**
 * Notifications when resources go online / offline.
**/
- (void)xmppRoster:(XMPPRosterMemoryStorage *)sender
    didAddResource:(XMPPResourceMemoryStorage *)resource
          withUser:(XMPPUserMemoryStorage *)user;

- (void)xmppRoster:(XMPPRosterMemoryStorage *)sender
 didUpdateResource:(XMPPResourceMemoryStorage *)resource
          withUser:(XMPPUserMemoryStorage *)user;

- (void)xmppRoster:(XMPPRosterMemoryStorage *)sender
 didRemoveResource:(XMPPResourceMemoryStorage *)resource
          withUser:(XMPPUserMemoryStorage *)user;

@end
