#import <Cocoa/Cocoa.h>
#import "XMPP.h"
#import "XMPPAutoTime.h"


@interface AutoTimeTestAppDelegate : NSObject <NSApplicationDelegate> {
@private
	XMPPStream *xmppStream;
	XMPPAutoTime *xmppAutoTime;
	
	NSWindow *window;
}

@property (assign) IBOutlet NSWindow *window;

@end
