#import <Cocoa/Cocoa.h>

@class XMPPSRVResolver;


@interface TestSRVResolverAppDelegate : NSObject <NSApplicationDelegate>
{
	XMPPSRVResolver *srvResolver;
	NSWindow *window;
}

@property (assign) IBOutlet NSWindow *window;

@end
