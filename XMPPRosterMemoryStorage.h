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
	NSMutableDictionary *roster;
	
	BOOL isRosterPopulation;
	
	XMPPUserMemoryStorage *myUser;
}

- (id)init;

@property (nonatomic, assign) XMPPRoster *parent;

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

- (void)xmppRosterDidChange:(XMPPRosterMemoryStorage *)sender;

@end
