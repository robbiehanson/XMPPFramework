#import <Foundation/Foundation.h>
#import "XMPPRoster.h"
#import "XMPPUserMemoryStorageObject.h"
#import "XMPPResourceMemoryStorageObject.h"


/**
 * This class is an example implementation of the XMPPRosterStorage protocol.
 * It simply keeps all roster informatin in memory.
 * 
 * You are free to substitute your own storage class.
**/

@interface XMPPRosterMemoryStorage : NSObject <XMPPRosterStorage>
{
  #if __has_feature(objc_arc_weak)
	__weak XMPPRoster *parent;
  #else
	__unsafe_unretained XMPPRoster *parent;
  #endif	
	dispatch_queue_t parentQueue;
	void *parentQueueTag;
	
	Class userClass;
	Class resourceClass;
	
	BOOL isRosterPopulation;
	NSMutableDictionary *roster;
	
	XMPPJID *myJID;
	XMPPUserMemoryStorageObject *myUser;
}

- (id)init;

@property (readonly) XMPPRoster *parent;

/**
 * You can optionally extend the XMPPUserMemoryStorage and XMPPResourceMemoryStorage classes.
 * Then just set the classes here, and your subclasses will automatically get used.
**/
@property (readwrite, assign) Class userClass;
@property (readwrite, assign) Class resourceClass;

/**
 * The methods below provide access to the roster data.
 * 
 * If invoked from a dispatch queue other than the roster's queue,
 * the methods return snapshots (copies) of the roster data.
 * These snapshots provide a thread-safe version of the roster data.
 * The thread-safety comes from the fact that the copied data will not be altered,
 * so it can therefore be used from multiple threads/queues if needed.
**/

- (XMPPUserMemoryStorageObject *)myUser;
- (XMPPResourceMemoryStorageObject *)myResource;

- (XMPPUserMemoryStorageObject *)userForJID:(XMPPJID *)jid;
- (XMPPResourceMemoryStorageObject *)resourceForJID:(XMPPJID *)jid;

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
- (void)xmppRoster:(XMPPRosterMemoryStorage *)sender didAddUser:(XMPPUserMemoryStorageObject *)user;
- (void)xmppRoster:(XMPPRosterMemoryStorage *)sender didUpdateUser:(XMPPUserMemoryStorageObject *)user;
- (void)xmppRoster:(XMPPRosterMemoryStorage *)sender didRemoveUser:(XMPPUserMemoryStorageObject *)user;

/**
 * Notifications when resources go online / offline.
**/
- (void)xmppRoster:(XMPPRosterMemoryStorage *)sender
    didAddResource:(XMPPResourceMemoryStorageObject *)resource
          withUser:(XMPPUserMemoryStorageObject *)user;

- (void)xmppRoster:(XMPPRosterMemoryStorage *)sender
 didUpdateResource:(XMPPResourceMemoryStorageObject *)resource
          withUser:(XMPPUserMemoryStorageObject *)user;

- (void)xmppRoster:(XMPPRosterMemoryStorage *)sender
 didRemoveResource:(XMPPResourceMemoryStorageObject *)resource
          withUser:(XMPPUserMemoryStorageObject *)user;

@end
