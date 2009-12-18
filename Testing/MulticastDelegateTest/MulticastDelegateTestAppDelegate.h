#import <Cocoa/Cocoa.h>
#import "MyProtocol.h"
#import "MulticastDelegate.h"

@class Class1;
@class Class2;

@interface MulticastDelegateTestAppDelegate : NSObject <NSApplicationDelegate>
{
	MulticastDelegate <MyProtocol> *multicastDelegate;
	
	Class1 *del1;
	Class2 *del2;
	
    NSWindow *window;
}

@property (assign) IBOutlet NSWindow *window;

@end
