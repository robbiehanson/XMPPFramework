#import <Cocoa/Cocoa.h>
#import "MyProtocol.h"
#import "GCDMulticastDelegate.h"

@class Class1;
@class Class2;

@interface MulticastDelegateTestAppDelegate : NSObject <NSApplicationDelegate>
{
	GCDMulticastDelegate <MyProtocol> *multicastDelegate;
	
	dispatch_queue_t queue1;
	dispatch_queue_t queue2;
	dispatch_queue_t queue3;
	
	Class1 *del1;
	Class2 *del2;
	
    NSWindow *window;
}

@property (assign) IBOutlet NSWindow *window;

@end
