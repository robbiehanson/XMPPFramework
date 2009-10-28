#import "AppDelegate.h"
#import "RosterController.h"
#import "XMPP.h"
#import "TURNSocket.h"


@implementation AppDelegate

- (id)init
{
	if((self = [super init]))
	{
		turnSockets = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	[xmppClient addDelegate:self];
	
	[rosterController displaySignInSheet];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XEP-0065 Support
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)connectViaXEP65:(XMPPJID *)jid
{
	if(jid == nil) return;
	
	NSLog(@"Attempting TURN connection to %@", jid);
	
	TURNSocket *turnSocket = [[TURNSocket alloc] initWithXMPPClient:xmppClient toJID:jid];
	
	[turnSockets addObject:turnSocket];
	
	[turnSocket start:self];
	[turnSocket release];
}

- (void)xmppClient:(XMPPClient *)sender didReceiveIQ:(XMPPIQ *)iq
{
	NSLog(@"---------- xmppClient:didReceiveIQ: ----------");
	
	if([TURNSocket isNewStartTURNRequest:iq])
	{
		TURNSocket *turnSocket = [[TURNSocket alloc] initWithXMPPClient:xmppClient incomingTURNRequest:iq];
		
		[turnSockets addObject:turnSocket];
		
		[turnSocket start:self];
		[turnSocket release];
	}
}

- (void)turnSocket:(TURNSocket *)sender didSucceed:(AsyncSocket *)socket
{
	NSLog(@"TURN Connection succeeded!");
	NSLog(@"You know have a socket that you can use to send/receive data to/from the other person.");
	
	// Now retain and use the socket.
	
	[turnSockets removeObject:sender];
}

- (void)turnSocketDidFail:(TURNSocket *)sender
{
	NSLog(@"TURN Connection failed!");
	
	[turnSockets removeObject:sender];
	
}

@end
