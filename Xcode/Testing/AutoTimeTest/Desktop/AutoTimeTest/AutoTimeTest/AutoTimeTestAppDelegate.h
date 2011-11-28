#import <Cocoa/Cocoa.h>
#import "XMPPFramework.h"


@interface AutoTimeTestAppDelegate : NSObject <NSApplicationDelegate> {
@private
	XMPPStream *xmppStream;
	XMPPAutoTime *xmppAutoTime;
	
	NSWindow *window;
}

@property (assign) IBOutlet NSWindow *window;

@end
