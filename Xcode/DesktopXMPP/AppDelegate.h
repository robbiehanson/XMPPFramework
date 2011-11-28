#import <Cocoa/Cocoa.h>
#import "XMPPFramework.h"

@class RosterController;


@interface AppDelegate : NSObject
{
	__strong XMPPStream *xmppStream;
	__strong XMPPReconnect *xmppReconnect;
	__strong XMPPRoster *xmppRoster;
	__strong XMPPRosterMemoryStorage *xmppRosterStorage;
	__strong XMPPCapabilities *xmppCapabilities;
	__strong XMPPCapabilitiesCoreDataStorage *xmppCapabilitiesStorage;
	__strong XMPPPing *xmppPing;
	__strong XMPPTime *xmppTime;
	
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
