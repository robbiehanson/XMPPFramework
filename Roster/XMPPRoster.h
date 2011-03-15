#import <Foundation/Foundation.h>
#import "MulticastDelegate.h"
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


@interface XMPPRoster : NSObject
{
  /*
   * XMPPStream is accessed by a background thread, do not change after init, 
   * without making atomic and updating all code to use the accessor method.
   */
	XMPPStream *xmppStream;   
	id <XMPPRosterStorage> xmppRosterStorage;
	
	MulticastDelegate <XMPPRosterDelegate> *multicastDelegate;
	
	Byte flags;
	
	NSMutableArray *earlyPresenceElements;
}

- (id)initWithStream:(XMPPStream *)xmppStream rosterStorage:(id <XMPPRosterStorage>)storage;

@property (nonatomic, readonly) XMPPStream *xmppStream;
@property (nonatomic, readonly) id <XMPPRosterStorage> xmppRosterStorage;

@property (nonatomic, assign) BOOL autoRoster;

- (void)addDelegate:(id)delegate;
- (void)removeDelegate:(id)delegate;

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
@optional

@property (nonatomic, assign) XMPPRoster *parent;

@required

- (id <XMPPUser>)myUserForXMPPStream:(XMPPStream *)xmppStream;
- (id <XMPPResource>)myResourceForXMPPStream:(XMPPStream *)xmppStream;

- (id <XMPPUser>)userForJID:(XMPPJID *)jid xmppStream:(XMPPStream *)xmppStream;
- (id <XMPPResource>)resourceForJID:(XMPPJID *)jid xmppStream:(XMPPStream *)xmppStream;

- (void)beginRosterPopulationForXMPPStream:(XMPPStream *)xmppStream;
- (void)endRosterPopulationForXMPPStream:(XMPPStream *)xmppStream;

- (void)handleRosterItem:(NSXMLElement *)item xmppStream:(XMPPStream *)xmppStream;
- (void)handlePresence:(XMPPPresence *)presence xmppStream:(XMPPStream *)xmppStream;

- (void)clearAllResourcesForXMPPStream:(XMPPStream *)xmppStream;
- (void)clearAllUsersAndResourcesForXMPPStream:(XMPPStream *)xmppStream;

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
