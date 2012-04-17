#import "MUCTestingAppDelegate.h"
#import "DDLog.h"
#import "DDTTYLogger.h"

// Log levels: off, error, warn, info, verbose
static const int ddLogLevel = LOG_LEVEL_VERBOSE;

#define XMPP_HOSTNAME_1  @"us-east3.pub.yak.tv"
#define XMPP_HOSTNAME_2  @"xmpp1.yap.tv"
#define XMPP_HOSTNAME_3  @"us-west1.yap.tv"

#define XMPP_JID         @"yap_user-214842@api.yap.tv"
#define XMPP_PASSWORD    @"XECGDhRBSzEYo7T92ywi"

#define ROOM_JID         @"robbie-test-xmppv3@conference.api.yap.tv"


@implementation MUCTestingAppDelegate

@synthesize window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	[DDLog addLogger:[DDTTYLogger sharedInstance]];
	
	xmppStream = [[XMPPStream alloc] init];
	
	xmppStream.hostName = XMPP_HOSTNAME_2;
	xmppStream.myJID = [XMPPJID jidWithString:XMPP_JID];
	
	[xmppStream addDelegate:self delegateQueue:dispatch_get_main_queue()];
	
	// Configure xmppRoom
	
	XMPPJID *roomJID = [XMPPJID jidWithString:ROOM_JID];
	
	xmppRoom = [[XMPPRoom alloc] initWithRoomStorage:self jid:roomJID];
	
	[xmppRoom activate:xmppStream];
	[xmppRoom addDelegate:self delegateQueue:dispatch_get_main_queue()];
	
	// Start connection process
	
	NSError *err = nil;
	if (![xmppStream connect:&err])
	{
		DDLogError(@"YapTesting: Cannot connect: %@", err);
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStream Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppStreamDidConnect:(XMPPStream *)sender
{
	DDLogInfo(@"%@: %@", THIS_FILE, THIS_METHOD);
	
	[xmppStream authenticateWithPassword:XMPP_PASSWORD error:nil];
}

- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender
{
	DDLogInfo(@"%@: %@", THIS_FILE, THIS_METHOD);
	
	[xmppRoom joinRoomUsingNickname:@"quack" history:nil];
}

- (void)xmppStream:(XMPPStream *)sender didNotAuthenticate:(NSXMLElement *)error
{
	DDLogInfo(@"%@: %@", THIS_FILE, THIS_METHOD);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPRoom Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppRoomDidCreate:(XMPPRoom *)sender
{
	DDLogInfo(@"%@: %@", THIS_FILE, THIS_METHOD);
}

- (void)xmppRoomDidJoin:(XMPPRoom *)sender
{
	DDLogInfo(@"%@: %@", THIS_FILE, THIS_METHOD);
	
	[xmppRoom fetchConfigurationForm];
	[xmppRoom fetchBanList];
	[xmppRoom fetchMembersList];
	[xmppRoom fetchModeratorsList];
}

- (void)xmppRoom:(XMPPRoom *)sender didFetchConfigurationForm:(NSXMLElement *)configForm
{
	DDLogInfo(@"%@: %@", THIS_FILE, THIS_METHOD);
}

- (void)xmppRoom:(XMPPRoom *)sender didFetchBanList:(NSArray *)items
{
	DDLogInfo(@"%@: %@", THIS_FILE, THIS_METHOD);
}

- (void)xmppRoom:(XMPPRoom *)sender didNotFetchBanList:(XMPPIQ *)iqError
{
	DDLogInfo(@"%@: %@", THIS_FILE, THIS_METHOD);
}

- (void)xmppRoom:(XMPPRoom *)sender didFetchMembersList:(NSArray *)items
{
	DDLogInfo(@"%@: %@", THIS_FILE, THIS_METHOD);
}

- (void)xmppRoom:(XMPPRoom *)sender didNotFetchMembersList:(XMPPIQ *)iqError
{
	DDLogInfo(@"%@: %@", THIS_FILE, THIS_METHOD);
}

- (void)xmppRoom:(XMPPRoom *)sender didFetchModeratorsList:(NSArray *)items
{
	DDLogInfo(@"%@: %@", THIS_FILE, THIS_METHOD);
}

- (void)xmppRoom:(XMPPRoom *)sender didNotFetchModeratorsList:(XMPPIQ *)iqError
{
	DDLogInfo(@"%@: %@", THIS_FILE, THIS_METHOD);
}

- (void)handleDidLeaveRoom:(XMPPRoom *)room
{
	DDLogInfo(@"%@: %@", THIS_FILE, THIS_METHOD);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPRoomStorage Protocol
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)handlePresence:(XMPPPresence *)presence room:(XMPPRoom *)room
{

}

- (void)handleIncomingMessage:(XMPPMessage *)message room:(XMPPRoom *)room
{

}

- (void)handleOutgoingMessage:(XMPPMessage *)message room:(XMPPRoom *)room
{

}

- (BOOL)configureWithParent:(XMPPRoom *)aParent queue:(dispatch_queue_t)queue
{
	return YES;
}

@end
