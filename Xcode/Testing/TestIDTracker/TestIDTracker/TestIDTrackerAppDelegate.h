#import <Cocoa/Cocoa.h>

@class XMPPIDTracker;


@interface TestIDTrackerAppDelegate : NSObject <NSApplicationDelegate>
{
	XMPPIDTracker *idTracker;
	
	NSString *fetch1;
	NSString *fetch2;
	NSString *fetch3;
	NSString *fetch4;
	NSString *fetch5;
	NSString *fetch6;
	NSString *fetch7;
	NSString *fetch8;
	
	NSWindow *window;
}

@property (assign) IBOutlet NSWindow *window;

@end
