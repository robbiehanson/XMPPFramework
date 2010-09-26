#import "AppDelegate.h"
#import "RosterController.h"
#import "XMPP.h"
#import "TURNSocket.h"

#if MAC_OS_X_VERSION_MIN_REQUIRED <= MAC_OS_X_VERSION_10_5
// SCNetworkConnectionFlags was renamed to SCNetworkReachabilityFlags in 10.6
typedef SCNetworkConnectionFlags SCNetworkReachabilityFlags;
#endif

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
	if((self = [super init]))
	{
		xmppStream = [[XMPPStream alloc] init];
		
	//	xmppReconnect = [[XMPPReconnect alloc] initWithStream:xmppStream];
		
		xmppRosterStorage = [[XMPPRosterMemoryStorage alloc] init];
		xmppRoster = [[XMPPRoster alloc] initWithStream:xmppStream
		                                  rosterStorage:xmppRosterStorage];
		
		xmppCapabilitiesStorage = [[XMPPCapabilitiesCoreDataStorage alloc] init];
		xmppCapabilities = [[XMPPCapabilities alloc] initWithStream:xmppStream
		                                        capabilitiesStorage:xmppCapabilitiesStorage];
		
		xmppCapabilities.autoFetchHashedCapabilities = YES;
		xmppCapabilities.autoFetchNonHashedCapabilities = NO;
		
		xmppPing = [[XMPPPing alloc] initWithStream:xmppStream];
		xmppTime = [[XMPPTime alloc] initWithStream:xmppStream];
		
		turnSockets = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	[xmppStream addDelegate:self];
	[xmppReconnect addDelegate:self];
	[xmppCapabilities addDelegate:self];
	[xmppPing addDelegate:self];
	[xmppTime addDelegate:self];
	
	[rosterController displaySignInSheet];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XEP-0065 Support
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)connectViaXEP65:(XMPPJID *)jid
{
	if(jid == nil) return;
	
	NSLog(@"Attempting TURN connection to %@", jid);
	
	TURNSocket *turnSocket = [[TURNSocket alloc] initWithStream:xmppStream toJID:jid];
	
	[turnSockets addObject:turnSocket];
	
	[turnSocket start:self];
	[turnSocket release];
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
	NSLog(@"---------- xmppStream:didReceiveIQ: ----------");
	
	if([TURNSocket isNewStartTURNRequest:iq])
	{
		TURNSocket *turnSocket = [[TURNSocket alloc] initWithStream:sender incomingTURNRequest:iq];
		
		[turnSockets addObject:turnSocket];
		
		[turnSocket start:self];
		[turnSocket release];
		
		return YES;
	}
	
	return NO;
}

- (void)turnSocket:(TURNSocket *)sender didSucceed:(AsyncSocket *)socket
{
	NSLog(@"TURN Connection succeeded!");
	NSLog(@"You now have a socket that you can use to send/receive data to/from the other person.");
	
	// Now retain and use the socket.
	
	[turnSockets removeObject:sender];
}

- (void)turnSocketDidFail:(TURNSocket *)sender
{
	NSLog(@"TURN Connection failed!");
	
	[turnSockets removeObject:sender];
	
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Auto Reconnect
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppStreamDidDisconnect:(XMPPStream *)sender
{
	// If we weren't using auto reconnect, we could take this opportunity to display the sign in sheet.
}

- (BOOL)xmppReconnect:(XMPPReconnect *)sender shouldAttemptAutoReconnect:(SCNetworkReachabilityFlags)reachabilityFlags
{
	NSLog(@"---------- xmppReconnect:shouldAttemptAutoReconnect: ----------");
	
	return YES;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Capabilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppCapabilities:(XMPPCapabilities *)sender didDiscoverCapabilities:(NSXMLElement *)caps forJID:(XMPPJID *)jid
{
	NSLog(@"---------- xmppCapabilities:didDiscoverCapabilities:forJID: ----------");
	NSLog(@"jid: %@", jid);
	NSLog(@"capabilities:\n%@", [caps XMLStringWithOptions:(NSXMLNodeCompactEmptyElement | NSXMLNodePrettyPrint)]);
}

@end
