#import <Cocoa/Cocoa.h>

@class RFSRVResolver;


@interface TestSRVResolverAppDelegate : NSObject <NSApplicationDelegate>
{
	RFSRVResolver *srvResolver;
	NSWindow *window;
}

@property (assign) IBOutlet NSWindow *window;

@end
