#import <Foundation/Foundation.h>
#import "XMPPModule.h"
#import "XMPPUser.h"
#import "XMPPResource.h"
#import "XMPPvCardAvatarModule.h"

#if TARGET_OS_IPHONE
  #import "DDXML.h"
#endif

@class XMPPJID;
@class XMPPStream;
@class XMPPPresence;
@protocol XMPPRosterStorage;
@protocol XMPPRosterDelegate;


/**
 * Add XMPPRoster as a delegate of XMPPvCardAvatarModule to cache roster photos in the roster.
 * This frees the view controller from having to save photos on the main thread.
 **/

@interface XMPPRoster : XMPPModule <XMPPvCardAvatarDelegate>
{
/*	Inherited from XMPPModule:
	
	XMPPStream *xmppStream;
 
	dispatch_queue_t moduleQueue;
	id multicastDelegate;
 */
	id <XMPPRosterStorage> xmppRosterStorage;
	
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

@property (nonatomic, readonly) id <XMPPRosterStorage> xmppRosterStorage;

@property (nonatomic, assign) BOOL autoRoster;

- (void)fetchRoster;

- (void)addBuddy:(XMPPJID *)jid withNickname:(NSString *)optionalName;
- (void)removeBuddy:(XMPPJID *)jid;

- (void)setNickname:(NSString *)nickname forBuddy:(XMPPJID *)jid;

- (void)acceptBuddyRequest:(XMPPJID *)jid;
- (void)rejectBuddyRequest:(XMPPJID *)jid;

- (id <XMPPUser>)myUser;
- (id <XMPPResource>)myResource;

- (id <XMPPUser>)userForJID:(XMPPJID *)jid;
- (id <XMPPResource>)resourceForJID:(XMPPJID *)jid;

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
// 

- (id <XMPPUser>)myUserForXMPPStream:(XMPPStream *)stream;
- (id <XMPPResource>)myResourceForXMPPStream:(XMPPStream *)stream;

- (id <XMPPUser>)userForJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream;
- (id <XMPPResource>)resourceForJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream;

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

- (void)clearAllResourcesForXMPPStream:(XMPPStream *)stream;
- (void)clearAllUsersAndResourcesForXMPPStream:(XMPPStream *)stream;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol XMPPRosterDelegate
@optional

/**
 * Sent when a buddy request is received.
 * 
 * The entire presence packet is provided for proper extensibility.
 * You can use [presence from] to get the JID of the buddy who sent the request.
**/
- (void)xmppRoster:(XMPPRoster *)sender didReceiveBuddyRequest:(XMPPPresence *)presence;

@end
