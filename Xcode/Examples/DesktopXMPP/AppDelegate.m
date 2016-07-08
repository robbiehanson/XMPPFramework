#import "AppDelegate.h"
#import "RosterController.h"
#import "XMPPLogging.h"
#import "DDLog.h"
#import "DDTTYLogger.h"

// Log levels: off, error, warn, info, verbose
static const int ddLogLevel = LOG_LEVEL_VERBOSE;


@implementation AppDelegate

@synthesize xmppStream;
@synthesize xmppReconnect;
@synthesize xmppRoster;
@synthesize xmppRosterStorage;
@synthesize xmppCapabilities;
@synthesize xmppCapabilitiesStorage;
@synthesize xmppPing;

- (id)init
{
	if ((self = [super init]))
	{
		// 
		// Configure logging framework
		// 
		// The XMPPFramework uses the CocoaLumberjack framework to provide fast & flexible logging.
		// There's tons of information about Lumberjack online:
		// https://github.com/robbiehanson/CocoaLumberjack
		// https://github.com/robbiehanson/CocoaLumberjack/wiki
		// 
		// But this one line is all we need to configure the logging framework to dump to the Xcode console.
		
        [DDLog addLogger:[DDTTYLogger sharedInstance] withLogLevel:XMPP_LOG_FLAG_SEND_RECV];
		
		// Initialize xmpp stream and modules
		
		xmppStream = [[XMPPStream alloc] init];
		
	//	xmppReconnect = [[XMPPReconnect alloc] init];
		
		xmppRosterStorage = [[XMPPRosterMemoryStorage alloc] init];
		xmppRoster = [[XMPPRoster alloc] initWithRosterStorage:xmppRosterStorage];
		
	//	xmppCapabilitiesStorage = [XMPPCapabilitiesCoreDataStorage sharedInstance];
	//	xmppCapabilities = [[XMPPCapabilities alloc] initWithCapabilitiesStorage:xmppCapabilitiesStorage];
		
	//	xmppCapabilities.autoFetchHashedCapabilities = YES;
	//	xmppCapabilities.autoFetchNonHashedCapabilities = NO;
		
	//	xmppPing = [[XMPPPing alloc] init];
	//	xmppTime = [[XMPPTime alloc] init];
		
		// Activate xmpp modules
		
		[xmppReconnect activate:xmppStream];
		[xmppRoster activate:xmppStream];
		[xmppCapabilities activate:xmppStream];
		[xmppPing activate:xmppStream];
		[xmppTime activate:xmppStream];
		
		// Add ourself as a delegate to anything we may be interested in
		
		[xmppReconnect addDelegate:self delegateQueue:dispatch_get_main_queue()];
		[xmppCapabilities addDelegate:self delegateQueue:dispatch_get_main_queue()];
		
		// Initialize other stuff
		
		turnSockets = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	DDLogInfo(@"%@: %@", THIS_FILE, THIS_METHOD);
	
	// Start the GUI stuff
	
	[rosterController displaySignInSheet];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XEP-0065 Support
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)connectViaXEP65:(XMPPJID *)jid
{
	if(jid == nil) return;
	
	DDLogInfo(@"Attempting TURN connection to %@", jid);
	
	TURNSocket *turnSocket = [[TURNSocket alloc] initWithStream:xmppStream toJID:jid];
	
	[turnSockets addObject:turnSocket];
	
	[turnSocket startWithDelegate:self delegateQueue:dispatch_get_main_queue()];
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
	DDLogVerbose(@"---------- xmppStream:didReceiveIQ: ----------");
	
	if ([TURNSocket isNewStartTURNRequest:iq])
	{
		TURNSocket *turnSocket = [[TURNSocket alloc] initWithStream:sender incomingTURNRequest:iq];
		
		[turnSockets addObject:turnSocket];
		
		[turnSocket startWithDelegate:self delegateQueue:dispatch_get_main_queue()];
		
		return YES;
	}
	
	return NO;
}

- (void)turnSocket:(TURNSocket *)sender didSucceed:(GCDAsyncSocket *)socket
{
	DDLogInfo(@"TURN Connection succeeded!");
	DDLogInfo(@"You now have a socket that you can use to send/receive data to/from the other person.");
	
	// Now retain and use the socket.
	
	[turnSockets removeObject:sender];
}

- (void)turnSocketDidFail:(TURNSocket *)sender
{
	DDLogInfo(@"TURN Connection failed!");
	
	[turnSockets removeObject:sender];
	
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Auto Reconnect
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)xmppReconnect:(XMPPReconnect *)sender shouldAttemptAutoReconnect:(SCNetworkReachabilityFlags)reachabilityFlags
{
	DDLogVerbose(@"---------- xmppReconnect:shouldAttemptAutoReconnect: ----------");
	
	return YES;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Capabilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppCapabilities:(XMPPCapabilities *)sender didDiscoverCapabilities:(NSXMLElement *)caps forJID:(XMPPJID *)jid
{
	DDLogVerbose(@"---------- xmppCapabilities:didDiscoverCapabilities:forJID: ----------");
	DDLogVerbose(@"jid: %@", jid);
	DDLogVerbose(@"capabilities:\n%@",
				 [caps XMLStringWithOptions:(NSXMLNodeCompactEmptyElement | NSXMLNodePrettyPrint)]);
}

@end
