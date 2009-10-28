#import <Cocoa/Cocoa.h>
@class  RosterController;
@class  XMPPClient;
@class  XMPPJID;


@interface AppDelegate : NSObject
{
	NSMutableArray *turnSockets;
	
	IBOutlet RosterController *rosterController;
	IBOutlet XMPPClient *xmppClient;
}

- (void)connectViaXEP65:(XMPPJID *)jid;

@end
