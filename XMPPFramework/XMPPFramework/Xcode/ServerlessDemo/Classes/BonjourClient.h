#import <Foundation/Foundation.h>


@interface BonjourClient : NSObject <NSNetServiceDelegate, NSNetServiceBrowserDelegate>
{
	NSNetServiceBrowser *serviceBrowser;
	NSMutableArray *services;
	
	NSNetService *localService;
}

+ (BonjourClient *)sharedInstance;

- (void)startBrowsing;
- (void)stopBrowsing;

- (void)publishServiceOnPort:(UInt16)port;

@end
