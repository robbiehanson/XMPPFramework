#import <Cocoa/Cocoa.h>
#import "XMPP.h"
#import "XMPPRoom.h"


@interface MUCTestingAppDelegate : NSObject <NSApplicationDelegate, XMPPRoomStorage>
{
	XMPPStream *xmppStream;
	XMPPRoom *xmppRoom;
	
	__unsafe_unretained NSWindow *window;
}

@property (unsafe_unretained) IBOutlet NSWindow *window;

@end
