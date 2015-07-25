#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE
    #import <UIKit/UIKit.h>
#else
    #import <Cocoa/Cocoa.h>
#endif

#import "XMPP.h"
#import "XMPPUser.h"
#import "XMPPResource.h"

#define _XMPP_ROSTER_H

@protocol XMPPRosterStorage;
@class DDList;
@class XMPPIDTracker;

/**
 * The XMPPRoster provides the scaffolding for a roster solution.
 * It handles the basics of the xmpp roster communication,
 * and leaves the rest up to the xmppRosterStorage classes.
 * 
 * You are free to extend, change, customize, or tweak the sample storage classes that come with the framework:
 * XMPPRosterMemoryStorage
 * XMPPRosterCoreDataStorage
 * 
 * You can also completely implment your own roster storage class if you'd like.
 * The point of all this customizability is simple:
 *   The roster is the component of the xmpp stack that is most often customized for a particular application.
 * 
 * 
 * Inter-Module Interaction:
 * 
 * If you use XMPPvCardAvatarModule, the roster will automatically support user photos.
**/
@interface XMPPRoster : XMPPModule
{
/*	Inherited from XMPPModule:
	
	XMPPStream *xmppStream;
 
	dispatch_queue_t moduleQueue;
	id multicastDelegate;
 */
	__strong id <XMPPRosterStorage> xmppRosterStorage;
    
    XMPPIDTracker *xmppIDTracker;
	
	Byte config;
	Byte flags;
	
	NSMutableArray *earlyPresenceElements;
	
	DDList *mucModules;
}

- (id)initWithRosterStorage:(id <XMPPRosterStorage>)storage;
- (id)initWithRosterStorage:(id <XMPPRosterStorage>)storage dispatchQueue:(dispatch_queue_t)queue;

/* Inherited from XMPPModule:

- (BOOL)activate:(XMPPStream *)xmppStream;
- (void)deactivate;

@property (readonly) XMPPStream *xmppStream;

- (void)addDelegate:(id)delegate delegateQueue:(dispatch_queue_t)delegateQueue;
- (void)removeDelegate:(id)delegate delegateQueue:(dispatch_queue_t)delegateQueue;
- (void)removeDelegate:(id)delegate;

- (NSString *)moduleName;
 
*/

@property (strong, readonly) id <XMPPRosterStorage> xmppRosterStorage;

/**
 * Whether or not to automatically fetch the roster from the server.
 * 
 * The default value is YES.
**/
@property (assign) BOOL autoFetchRoster;

/**
 * Whether or not to automatically clear all Users and Resources when the stream disconnects.
 * If you are using XMPPRosterCoreDataStorage you may want to set autoRemovePreviousDatabaseFile to NO.
 *
 * All Users and Resources will be cleared when the roster is next populated regardless of this property.
 *
 * The default value is YES.
**/
@property (assign) BOOL autoClearAllUsersAndResources;

/**
 * In traditional IM applications, the "buddy" system is rather straightforward.
 * User A sends a request to become "friends" with user B.
 * User B accepts the friend request.
 * And now user A and B appear in each other's roster.
 * 
 * But, internally, XMPP presence actually works more like twitter.
 * User A sends a presence subscription request to user B.
 * Think about this more like following on twitter.
 * User A is requesting permission to receive presence information from user B (following their presence).
 * User B can accept this request, but may not be interested in receiving presence info from user B.
 * Again, this is more like twitter following, but with the addition of required permission.
 * So when user B accepts the request, this *only* means that user A will receive presence from user B.
 * It does *not* mean that user B will receive presence from user A.
 * Again, twitter-style, user A is now "following" user B.
 * In diagram form, presence is flowing like this:
 * 
 *   A <-- B
 * 
 * Now, if B also wants to receive presence from user A, then user B must request this permission.
 * And furthermore, user A must accept the request.
 * Just because B has granted A permission to receive presence,
 * doesn't mean that B gets a free pass to receive presence from A.
 * Presence always requires permission.
 * 
 * This property does the following:
 * If a presence subscription request is received from user X,
 * and user X has already been added to our roster (is a "known" user),
 * then the presence subscription request is automatically accepted.
 * 
 * Continuing the example from above, if we were user A, and we've already added B to our roster,
 * then if B sends a presence susbcription request, we'll auto accept it.
 * 
 * This makes the roster act more like traditional IM applications.
 * 
 * The default value is YES.
**/
@property (assign) BOOL autoAcceptKnownPresenceSubscriptionRequests;

/**
 * Allows the roster module to function without ever fetching the full roster.
 * This is helpful for situations in which the roster is very big, yet the application only cares about online users.
 * 
 * Typically, the roster module creates users based on the fetched full roster,
 * and then creates resources based on received presence.
 * 
 * In this mode, the roster module will automatically create a user once a presence is received,
 * if the user has never been seen before.
 * 
 * If allowRosterlessOperation is enabled, and autoFetchRoster is disabled (and roster is never manually fetched),
 * then XMPPUser's will be missing certain information that is only available via a roster fetch
 * (such as nickname, group, and subscription information).
 * 
 * The default value is NO.
**/
@property (assign) BOOL allowRosterlessOperation;

/**
 * The roster has either been requested manually (fetchRoster:)
 * or automatically (autoFetchRoster) but has yet to be populated.
**/
@property (assign, getter = hasRequestedRoster, readonly) BOOL requestedRoster;

/**
 * The initial roster has been received by client and is currently being populated.
 * @see xmppRosterDidBeginPopulating:withVersion:
 * @see xmppRosterDidEndPopulating:
**/
@property (assign, getter = isPopulating, readonly) BOOL populating;

/**
 * The initial roster has been received by client and populated.
**/
@property (assign, readonly) BOOL hasRoster;

/**
 * Manually fetch the roster from the server.
 * Useful if you disable autoFetchRoster.
**/
- (void)fetchRoster;
- (void)fetchRosterVersion:(NSString *)version;

/**
 * Adds the given user to the roster with an optional nickname 
 * and requests permission to receive presence information from them.
**/
- (void)addUser:(XMPPJID *)jid withNickname:(NSString *)optionalName;

/**
 * Adds the given user to the roster with an optional nickname, 
 * adds the given user to groups
 * and requests permission to receive presence information from them.
**/
- (void)addUser:(XMPPJID *)jid withNickname:(NSString *)optionalName groups:(NSArray *)groups;

/**
 * Adds the given user to the roster with an optional nickname,
 * adds the given user to groups
 * and optionally requests permission to receive presence information from them.
**/
- (void)addUser:(XMPPJID *)jid withNickname:(NSString *)optionalName groups:(NSArray *)groups subscribeToPresence:(BOOL)subscribe;

/**
 * Sets/modifies the nickname for the given user.
**/
- (void)setNickname:(NSString *)nickname forUser:(XMPPJID *)jid;

/**
 * Remove the user from the roster, unsubscribe from their presence, AND
 * revoke given user's permission to receive our presence (if they have such permission).
 * 
 * This is similar to removing a buddy in a traditional IM model.
 * 
 * @see unsubscribePresenceFromUser:
 * @see revokePresencePermissionFromUser:
**/
- (void)removeUser:(XMPPJID *)jid;

/**
 * If we don't currently receive presence from the given user,
 * this method requests a subscription to start receiving presence updates from the given user.
 * 
 * This is similar to following in the twitter model.
 * 
 * Note: If the given user isn't already in the roster, it is recommended to instead use addUser:withNickname:.
 * 
 * @see addUser:withNickname:
**/
- (void)subscribePresenceToUser:(XMPPJID *)jid;

/**
 * If we currently have a presence subscription to the given user,
 * this method then removes the subscription.
 * 
 * This is similar to unfollowing in the twitter model.
 * 
 * If the given user has a presence subscription to us (they're following our presence),
 * then their presence subscription to us is left intact.
 * 
 * @see removeUser:
 * @see revokePresencePermissionFromUser:
**/
- (void)unsubscribePresenceFromUser:(XMPPJID *)jid;

/**
 * If we have previously accepted a presence subscription request from the given user,
 * this method revokes the previously granted permission.
 * 
 * This is similar to forcing the given user to unfollow us in the twitter model.
 * 
 * If we have a presence subscription to the given user (we're following their presence),
 * then our presence subscription to them is left intact.
 * 
 * @see removeUser:
 * @see unsubscribePresenceFromUser:
**/
- (void)revokePresencePermissionFromUser:(XMPPJID *)jid;

/**
 * Accepts the presence subscription request the given user.
 * 
 * If you also choose, you can add the user to your roster.
 * Doing so is similar to the traditional IM model.
**/
- (void)acceptPresenceSubscriptionRequestFrom:(XMPPJID *)jid andAddToRoster:(BOOL)flag;

/**
 * Rejects the presence subscription request from the given user.
 * 
 * If you are already subscribed to the given user's presence,
 * rejecting they subscription request will not affect your subscription to their presence.
**/
- (void)rejectPresenceSubscriptionRequestFrom:(XMPPJID *)jid;

// 
// 
// You can access/enumerate the users & resources via the roster storage class (xmppRosterStorage property).
// 
// Rember, XMPPRoster is just the scaffolding for a complete and customizable roster solution.
// The roster storage classes hold the majority of the magic.
// 
// And since you're free to plug-n-play storage classes, and customize them as much as you want.
// This is where you can really tailor the xmpp stack to meet the needs of your application.
// 
// 

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol XMPPRosterStorage <NSObject>
@required

// 
// 
// -- PUBLIC METHODS --
// 
// There are no public methods required by this protocol.
// 
// Each individual roster storage class will provide a proper way to access/enumerate the
// users/resources according to the underlying storage mechanism.
// 


// 
// 
// -- PRIVATE METHODS --
// 
// These methods are designed to be used ONLY by the XMPPRoster class.
// 
// 

/**
 * Configures the storage class, passing its parent and parent's dispatch queue.
 * 
 * This method is called by the init method of the XMPPRoster class.
 * This method is designed to inform the storage class of its parent
 * and of the dispatch queue the parent will be operating on.
 * 
 * The storage class may choose to operate on the same queue as its parent,
 * or it may operate on its own internal dispatch queue.
 * 
 * This method should return YES if it was configured properly.
 * If a storage class is designed to be used with a single parent at a time, this method may return NO.
 * The XMPPRoster class is configured to ignore the passed
 * storage class in its init method if this method returns NO.
**/
- (BOOL)configureWithParent:(XMPPRoster *)aParent queue:(dispatch_queue_t)queue;

- (void)beginRosterPopulationForXMPPStream:(XMPPStream *)stream withVersion:(NSString *)version;
- (void)endRosterPopulationForXMPPStream:(XMPPStream *)stream;

- (void)handleRosterItem:(NSXMLElement *)item xmppStream:(XMPPStream *)stream;
- (void)handlePresence:(XMPPPresence *)presence xmppStream:(XMPPStream *)stream;

- (BOOL)userExistsWithJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream;

- (void)clearAllResourcesForXMPPStream:(XMPPStream *)stream;
- (void)clearAllUsersAndResourcesForXMPPStream:(XMPPStream *)stream;

- (NSArray *)jidsForXMPPStream:(XMPPStream *)stream;

- (void)getSubscription:(NSString **)subscription
                    ask:(NSString **)ask
               nickname:(NSString **)nickname
                 groups:(NSArray **)groups
                 forJID:(XMPPJID *)jid
             xmppStream:(XMPPStream *)stream;

@optional

/**
 * When XMPPvCardAvatarModule is included in the framework, the roster will integrate with it.
 * Implement this method to provide support for storing the downloaded user photos.
**/
#if TARGET_OS_IPHONE
- (void)setPhoto:(UIImage *)image forUserWithJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream;
#else
- (void)setPhoto:(NSImage *)image forUserWithJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream;
#endif

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol XMPPRosterDelegate
@optional

/**
 * Sent when a presence subscription request is received.
 * That is, another user has added you to their roster,
 * and is requesting permission to receive presence broadcasts that you send.
 * 
 * The entire presence packet is provided for proper extensibility.
 * You can use [presence from] to get the JID of the user who sent the request.
 * 
 * The methods acceptPresenceSubscriptionRequestFrom: and rejectPresenceSubscriptionRequestFrom: can
 * be used to respond to the request.
**/
- (void)xmppRoster:(XMPPRoster *)sender didReceivePresenceSubscriptionRequest:(XMPPPresence *)presence;

/**
 * Sent when a Roster Push is received as specified in Section 2.1.6 of RFC 6121.
**/
- (void)xmppRoster:(XMPPRoster *)sender didReceiveRosterPush:(XMPPIQ *)iq;

/**
 * Sent when the initial roster is received.
**/
- (void)xmppRosterDidBeginPopulating:(XMPPRoster *)sender withVersion:(NSString *)version;

/**
 * Sent when the initial roster has been populated into storage.
**/
- (void)xmppRosterDidEndPopulating:(XMPPRoster *)sender;

/**
 * Sent when the roster receives a roster item.
 *
 * Example:
 *
 * <item jid='romeo@example.net' name='Romeo' subscription='both'>
 *   <group>Friends</group>
 * </item>
**/
- (void)xmppRoster:(XMPPRoster *)sender didReceiveRosterItem:(NSXMLElement *)item;

@end
