#import <Cocoa/Cocoa.h>
#import "XMPPFramework.h"


@interface AutoTimeTestAppDelegate : NSObject <NSApplicationDelegate> {
@private
	XMPPStream *xmppStream;
	XMPPAutoTime *xmppAutoTime;
	
	NSWindow *__unsafe_unretained window;
}

@property (unsafe_unretained) IBOutlet NSWindow *window;

@end
