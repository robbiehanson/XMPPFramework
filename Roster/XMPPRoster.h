#import <Foundation/Foundation.h>
#import "XMPPModule.h"
#import "XMPPUser.h"
#import "XMPPResource.h"

#if TARGET_OS_IPHONE
  #import "DDXML.h"
#endif

@class XMPPJID;
@class XMPPStream;
@class XMPPPresence;
@protocol XMPPRosterStorage;
@protocol XMPPRosterDelegate;


@interface XMPPRoster : XMPPModule
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

@property (nonatomic, readonly) XMPPRoster *parent;

- (id <XMPPUser>)myUser;
- (id <XMPPResource>)myResource;

- (id <XMPPUser>)userForJID:(XMPPJID *)jid;
- (id <XMPPResource>)resourceForJID:(XMPPJID *)jid;

// 
// 
// -- PRIVATE METHODS --
// 
// These methods are designed to be used ONLY by the XMPPRoster class.
// 
// 

- (void)beginRosterPopulation;
- (void)endRosterPopulation;

- (void)handleRosterItem:(NSXMLElement *)item;
- (void)handlePresence:(XMPPPresence *)presence;

- (void)clearAllResources;
- (void)clearAllUsersAndResources;

/**
 * Configures the storage class, passing it's parent and parent's dispatch queue.
 * 
 * This method is called by the init method of the XMPPRoster class.
 * This method is designed to inform the storage class of it's parent
 * and of the dispatch queue the parent will be operating on.
 * 
 * It is strongly recommended the storage class operate on the same queue as it's parent
 * as the majority of the time it will be getting called by the parent.
 * Thus if both are operating on the same queue, the combination can run faster.
 * 
 * This method should return YES if it was configured properly.
 * A storage class is generally meant to be used once, and only with a single parent at a time.
 * Thus if you attempt to use a single storage class with multiple parents, this method may return NO.
 * The XMPPRoster class is configured to ignore the passed
 * storage class in its init method if this method returns NO.
**/
- (BOOL)configureWithParent:(XMPPRoster *)aParent queue:(dispatch_queue_t)queue;

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
