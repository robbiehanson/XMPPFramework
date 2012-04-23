#import <Cocoa/Cocoa.h>
#import "XMPPFramework.h"


@interface AutoTimeTestAppDelegate : NSObject <NSApplicationDelegate> {
@private
	XMPPStream *xmppStream;
	XMPPAutoTime *xmppAutoTime;
	
	__unsafe_unretained NSWindow *window;
}

@property (unsafe_unretained) IBOutlet NSWindow *window;

@end
