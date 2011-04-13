#import <Cocoa/Cocoa.h>
#import "XMPP.h"
#import "XMPPAutoPing.h"


@interface AutoPingTestAppDelegate : NSObject <NSApplicationDelegate> {
@private
	XMPPStream *xmppStream;
	XMPPAutoPing *xmppAutoPing;
	
	NSWindow *window;
}

@property (assign) IBOutlet NSWindow *window;

@end
