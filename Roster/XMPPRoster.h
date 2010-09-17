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

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol XMPPRosterStorage <NSObject>
@required

@property (nonatomic, assign) XMPPRoster *parent;

- (id <XMPPUser>)myUser;
- (id <XMPPResource>)myResource;

- (id <XMPPUser>)userForJID:(XMPPJID *)jid;
- (id <XMPPResource>)resourceForJID:(XMPPJID *)jid;

- (void)beginRosterPopulation;
- (void)endRosterPopulation;

- (void)handleRosterItem:(NSXMLElement *)item;
- (void)handlePresence:(XMPPPresence *)presence;

- (void)clearAllResources;
- (void)clearAllUsersAndResources;

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
