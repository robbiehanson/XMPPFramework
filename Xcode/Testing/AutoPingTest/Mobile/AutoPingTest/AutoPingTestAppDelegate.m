#import "AutoPingTestAppDelegate.h"
#import "AutoPingTestViewController.h"
#import "DDLog.h"
#import "DDTTYLogger.h"

// Log levels: off, error, warn, info, verbose
static const int ddLogLevel = LOG_LEVEL_VERBOSE;

#define MY_JID      @"" // <--- ENTER A JID HERE (e.g. user@gmail.com)
#define MY_PASSWORD @"" // <--- ENTER PASSWORD HERE


@implementation AutoPingTestAppDelegate

@synthesize window = _window;
@synthesize viewController = _viewController;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	[DDLog addLogger:[DDTTYLogger sharedInstance]];
	
	DDLogVerbose(@"%@: %@", [self class], THIS_METHOD);
	
	xmppStream = [[XMPPStream alloc] init];
	
//	xmppStream.hostName = @"";
	xmppStream.myJID = [XMPPJID jidWithString:MY_JID];
	
	xmppAutoPing = [[XMPPAutoPing alloc] init];
	xmppAutoPing.pingInterval = 30;
	xmppAutoPing.pingTimeout = 5;
	xmppAutoPing.targetJID = nil;
	
	[xmppAutoPing activate:xmppStream];
	
	[xmppStream addDelegate:self delegateQueue:dispatch_get_main_queue()];
	[xmppAutoPing addDelegate:self delegateQueue:dispatch_get_main_queue()];
	
	NSError *error = nil;
	
	if (![xmppStream connect:&error])
	{
		DDLogError(@"%@: Error connecting: %@", [self class], error);
	}
	 
	self.window.rootViewController = self.viewController;
	[self.window makeKeyAndVisible];
    return YES;
}

- (void)goOnline:(NSTimer *)aTimer
{
	DDLogVerbose(@"%@: %@", [self class], THIS_METHOD);
	
	[xmppStream sendElement:[XMPPPresence presence]];
}

- (void)goOffline:(NSTimer *)aTimer
{
	DDLogVerbose(@"%@: %@", [self class], THIS_METHOD);
	
	[xmppStream sendElement:[XMPPPresence presenceWithType:@"unavailable"]];
}

- (void)changeAutoPingInterval:(NSTimer *)aTimer
{
	DDLogVerbose(@"%@: %@", [self class], THIS_METHOD);
	
	xmppAutoPing.pingInterval = 60;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppStreamDidConnect:(XMPPStream *)sender
{
	DDLogVerbose(@"%@: %@", [self class], THIS_METHOD);
	
	NSError *error = nil;
	
	if (![xmppStream authenticateWithPassword:MY_PASSWORD error:&error])
	{
		DDLogError(@"%@: Error authenticating: %@", [self class], error);
	}
}

- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender
{
	DDLogVerbose(@"%@: %@", [self class], THIS_METHOD);
	
	[NSTimer scheduledTimerWithTimeInterval:45 target:self selector:@selector(goOnline:) userInfo:nil repeats:NO];
	[NSTimer scheduledTimerWithTimeInterval:90 target:self selector:@selector(changeAutoPingInterval:) userInfo:nil repeats:NO];
}

- (void)xmppStream:(XMPPStream *)sender didNotAuthenticate:(NSXMLElement *)error
{
	DDLogVerbose(@"%@: %@", [self class], THIS_METHOD);
}

- (void)xmppStreamDidDisconnect:(XMPPStream *)sender withError:(NSError *)error
{
	DDLogVerbose(@"%@: %@", [self class], THIS_METHOD);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppAutoPingDidSendPing:(XMPPAutoPing *)sender
{
	DDLogVerbose(@"%@: %@", [self class], THIS_METHOD);
}

- (void)xmppAutoPingDidReceivePong:(XMPPAutoPing *)sender
{
	DDLogVerbose(@"%@: %@", [self class], THIS_METHOD);
}

- (void)xmppAutoPingDidTimeout:(XMPPAutoPing *)sender
{
	DDLogVerbose(@"%@: %@", [self class], THIS_METHOD);
}

@end
