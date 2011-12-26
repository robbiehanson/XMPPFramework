#import <Cocoa/Cocoa.h>
#import "XMPP.h"
#import "XMPPRoom.h"


@interface MUCTestingAppDelegate : NSObject <NSApplicationDelegate, XMPPRoomStorage>
{
	XMPPStream *xmppStream;
	XMPPRoom *xmppRoom;
	
	NSWindow *window;
}

@property (assign) IBOutlet NSWindow *window;

@end
