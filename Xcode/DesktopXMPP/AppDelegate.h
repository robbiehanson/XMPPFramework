#import <Cocoa/Cocoa.h>
#import "XMPP.h"
#import "XMPPReconnect.h"
#import "XMPPRoster.h"
#import "XMPPRosterMemoryStorage.h"
#import "XMPPCapabilities.h"
#import "XMPPCapabilitiesCoreDataStorage.h"
#import "XMPPPing.h"

@class  RosterController;


@interface AppDelegate : NSObject
{
	XMPPStream *xmppStream;
	XMPPReconnect *xmppReconnect;
	XMPPRoster *xmppRoster;
	XMPPRosterMemoryStorage *xmppRosterStorage;
	XMPPCapabilities *xmppCapabilities;
	XMPPCapabilitiesCoreDataStorage *xmppCapabilitiesStorage;
	XMPPPing *xmppPing;
	
	NSMutableArray *turnSockets;
	
	IBOutlet RosterController *rosterController;
}

@property (nonatomic, readonly) XMPPStream *xmppStream;
@property (nonatomic, readonly) XMPPReconnect *xmppReconnect;
@property (nonatomic, readonly) XMPPRoster *xmppRoster;
@property (nonatomic, readonly) XMPPRosterMemoryStorage *xmppRosterStorage;
@property (nonatomic, readonly) XMPPCapabilities *xmppCapabilities;
@property (nonatomic, readonly) XMPPCapabilitiesCoreDataStorage *xmppCapabilitiesStorage;
@property (nonatomic, readonly) XMPPPing *xmppPing;

- (void)connectViaXEP65:(XMPPJID *)jid;

@end
