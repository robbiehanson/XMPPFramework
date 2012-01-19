#import <Cocoa/Cocoa.h>

@class XMPPSRVResolver;


@interface TestSRVResolverAppDelegate : NSObject <NSApplicationDelegate>
{
	XMPPSRVResolver *srvResolver;
	__unsafe_unretained NSWindow *window;
}

@property (unsafe_unretained) IBOutlet NSWindow *window;

@end
