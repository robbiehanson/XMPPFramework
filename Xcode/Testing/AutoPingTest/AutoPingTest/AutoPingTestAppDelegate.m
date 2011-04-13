#import "AutoPingTestAppDelegate.h"

#define DEBUG_LEVEL 4
#include "DDLog.h"

#define MY_JID      @"robbie@robbiehanson.com/rsrc"
#define MY_PASSWORD @"secret"


@implementation AutoPingTestAppDelegate

@synthesize window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	xmppStream = [[XMPPStream alloc] init];
	[xmppStream setMyJID:[XMPPJID jidWithString:MY_JID]];
	
	xmppAutoPing = [[XMPPAutoPing alloc] initWithStream:xmppStream];
	xmppAutoPing.pingInterval = 15;
	xmppAutoPing.pingTimeout = 5;
	xmppAutoPing.targetJID = nil;
	
	[xmppStream addDelegate:self];
	[xmppAutoPing addDelegate:self];
	
	NSError *error = nil;
	
	if (![xmppStream connect:&error])
	{
		DDLogError(@"%@: Error connecting: %@", [self class], error);
	}
}

- (void)goOnline:(NSTimer *)aTimer
{
	DDLogInfo(@"%@: %@", [self class], THIS_METHOD);
	
	[xmppStream sendElement:[XMPPPresence presence]];
}

- (void)goOffline:(NSTimer *)aTimer
{
	DDLogInfo(@"%@: %@", [self class], THIS_METHOD);
	
	[xmppStream sendElement:[XMPPPresence presenceWithType:@"unavailable"]];
}

- (void)changeAutoPingInterval:(NSTimer *)aTimer
{
	DDLogInfo(@"%@: %@", [self class], THIS_METHOD);
	
	xmppAutoPing.pingInterval = 30;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppStreamDidConnect:(XMPPStream *)sender
{
	DDLogInfo(@"%@: %@", [self class], THIS_METHOD);
	
	NSError *error = nil;
	
	if (![xmppStream authenticateWithPassword:MY_PASSWORD error:&error])
	{
		DDLogError(@"%@: Error authenticating: %@", [self class], error);
	}
}

- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender
{
	DDLogInfo(@"%@: %@", [self class], THIS_METHOD);
	
	[NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(goOnline:) userInfo:nil repeats:NO];
	[NSTimer scheduledTimerWithTimeInterval:30 target:self selector:@selector(goOffline:) userInfo:nil repeats:NO];
	[NSTimer scheduledTimerWithTimeInterval:35 target:self selector:@selector(changeAutoPingInterval:) userInfo:nil repeats:NO];
}

- (void)xmppStream:(XMPPStream *)sender didNotAuthenticate:(NSXMLElement *)error
{
	DDLogInfo(@"%@: %@", [self class], THIS_METHOD);
}

- (void)xmppStreamDidDisconnect:(XMPPStream *)sender
{
	DDLogInfo(@"%@: %@", [self class], THIS_METHOD);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppAutoPingDidSendPing:(XMPPAutoPing *)sender
{
	DDLogInfo(@"%@: %@", [self class], THIS_METHOD);
}

- (void)xmppAutoPingDidReceivePong:(XMPPAutoPing *)sender
{
	DDLogInfo(@"%@: %@", [self class], THIS_METHOD);
}

- (void)xmppAutoPingDidTimeout:(XMPPAutoPing *)sender
{
	NSLog(@"%@: %@", [self class], THIS_METHOD);
}

@end
