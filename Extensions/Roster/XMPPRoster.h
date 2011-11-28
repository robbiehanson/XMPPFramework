#import <Foundation/Foundation.h>

#if !TARGET_OS_IPHONE
  #import <Cocoa/Cocoa.h>
#endif

#import "XMPP.h"
#import "XMPPUser.h"
#import "XMPPResource.h"

@protocol XMPPRosterStorage;


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
	
	Byte config;
	Byte flags;
	
	NSMutableArray *earlyPresenceElements;
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
 * Manually fetch the roster from the server.
 * Useful if you disable autoFetchRoster.
**/
- (void)fetchRoster;

/**
 * Adds the given user to the roster and requests permission to receive presence information from them.
**/
- (void)addUser:(XMPPJID *)jid withNickname:(NSString *)optionalName;

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
// And since you're free to plug-n-play storage classes, and customize them as much as you want,
// this is where you can really tailor the xmpp stack to meet the needs of your application.
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

- (void)beginRosterPopulationForXMPPStream:(XMPPStream *)stream;
- (void)endRosterPopulationForXMPPStream:(XMPPStream *)stream;

- (void)handleRosterItem:(NSXMLElement *)item xmppStream:(XMPPStream *)stream;
- (void)handlePresence:(XMPPPresence *)presence xmppStream:(XMPPStream *)stream;

- (BOOL)userExistsWithJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream;

- (void)clearAllResourcesForXMPPStream:(XMPPStream *)stream;
- (void)clearAllUsersAndResourcesForXMPPStream:(XMPPStream *)stream;

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

@end
