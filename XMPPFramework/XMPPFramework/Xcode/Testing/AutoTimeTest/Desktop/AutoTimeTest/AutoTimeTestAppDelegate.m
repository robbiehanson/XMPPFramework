#import "AutoTimeTestAppDelegate.h"
#import "DDLog.h"
#import "DDTTYLogger.h"

// Log levels: off, error, warn, info, verbose
static const int ddLogLevel = LOG_LEVEL_VERBOSE;

#define MY_JID      @"" // <--- ENTER A JID HERE (e.g. user@gmail.com)
#define MY_PASSWORD @"" // <--- ENTER PASSWORD HERE


@implementation AutoTimeTestAppDelegate

@synthesize window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	[DDLog addLogger:[DDTTYLogger sharedInstance]];
	
	DDLogVerbose(@"%@: %@", [self class], THIS_METHOD);
	
	xmppStream = [[XMPPStream alloc] init];
	
//	xmppStream.hostName = @"";
	xmppStream.myJID = [XMPPJID jidWithString:MY_JID];
	
	xmppAutoTime = [[XMPPAutoTime alloc] init];
	xmppAutoTime.recalibrationInterval = 60;
	xmppAutoTime.targetJID = nil;
	
	[xmppAutoTime activate:xmppStream];
	
	[xmppStream addDelegate:self delegateQueue:dispatch_get_main_queue()];
	[xmppAutoTime addDelegate:self delegateQueue:dispatch_get_main_queue()];
	
	NSError *error = nil;
	
	if (![xmppStream connect:&error])
	{
		DDLogError(@"%@: Error connecting: %@", [self class], error);
	}
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

- (void)changeAutoTimeInterval:(NSTimer *)aTimer
{
	DDLogVerbose(@"%@: %@", [self class], THIS_METHOD);
	
	xmppAutoTime.recalibrationInterval = 30;
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
	
	[NSTimer scheduledTimerWithTimeInterval:130
	                                 target:self
	                               selector:@selector(changeAutoTimeInterval:)
	                               userInfo:nil
	                                repeats:NO];
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

- (void)xmppAutoTime:(XMPPAutoTime *)sender didUpdateTimeDifference:(NSTimeInterval)timeDifference
{
	DDLogVerbose(@"%@: %@ %f <<<<<<<============", [self class], THIS_METHOD, timeDifference);
}

@end
