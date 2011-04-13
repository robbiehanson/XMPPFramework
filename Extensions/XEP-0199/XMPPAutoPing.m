#import "XMPPAutoPing.h"
#import "XMPP.h"

@interface XMPPAutoPing ()
- (void)updatePingIntervalTimer;
- (void)stopPingIntervalTimer;
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPAutoPing

@synthesize pingInterval;
@synthesize pingTimeout;
@synthesize targetJID;
@synthesize lastReceiveTime;

- (id)initWithStream:(XMPPStream *)aXmppStream
{
	if ((self = [super initWithStream:aXmppStream]))
	{
		pingInterval = 60;
		pingTimeout = 10;
		
		lastReceiveTime = nil;
		
		xmppPing = [[XMPPPing alloc] initWithStream:aXmppStream respondsToQueries:NO];
		
		[xmppPing addDelegate:self];
	}
	return self;
}

- (void)dealloc
{
	[targetJID release];
	[targetJIDStr release];
	[lastReceiveTime release];
	
	[self stopPingIntervalTimer];
	
	[xmppPing removeDelegate:self];
	[xmppPing release];
	
    [super dealloc];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Properties
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)setPingInterval:(NSTimeInterval)interval
{
	if (pingInterval != interval)
	{
		pingInterval = interval;
		
		[self updatePingIntervalTimer];
	}
}

- (void)setTargetJID:(XMPPJID *)jid
{
	if (![targetJID isEqual:jid])
	{
		[targetJID release];
		targetJID = [jid retain];
		
		[targetJIDStr release];
		targetJIDStr = [[targetJID full] retain];
	}
}

- (void)updateLastReceiveTime
{
	[lastReceiveTime release];
	lastReceiveTime = [[NSDate alloc] init];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Ping Interval
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)handlePingIntervalTimerFire
{
	if (awaitingPingResponse) return;
	
	BOOL sendPing = NO;
	
	if (lastReceiveTime == nil)
	{
		sendPing = YES;
	}
	else
	{
		NSTimeInterval elapsed = [lastReceiveTime timeIntervalSinceNow] * -1.0;
		
		sendPing = (elapsed >= pingInterval);
	}
	
	if (sendPing)
	{
		awaitingPingResponse = YES;
		
		if (targetJID)
			[xmppPing sendPingToJID:targetJID withTimeout:pingTimeout];
		else
			[xmppPing sendPingToServerWithTimeout:pingTimeout];
		
		[multicastDelegate xmppAutoPingDidSendPing:self];
	}
}

- (void)updatePingIntervalTimer
{
	// Todo...
}

- (void)startPingIntervalTimer
{
	// Todo...
}

- (void)stopPingIntervalTimer
{
	if (pingIntervalTimer)
	{
		[pingIntervalTimer invalidate];
		[pingIntervalTimer release];
		pingIntervalTimer = nil;
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPPing Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppPing:(XMPPPing *)sender didReceivePong:(XMPPIQ *)pong withRTT:(NSTimeInterval)rtt
{
	awaitingPingResponse = NO;
	[multicastDelegate xmppAutoPingDidReceivePong:self];
}

- (void)xmppPing:(XMPPPing *)sender didNotReceivePong:(NSString *)pingID dueToTimeout:(NSTimeInterval)timeout
{
	awaitingPingResponse = NO;
	[multicastDelegate xmppAutoPingDidTimeout:self];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStream Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender
{
	[self updateLastReceiveTime];
	awaitingPingResponse = NO;
	
	[self startPingIntervalTimer];
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
	if (targetJID == nil || [targetJIDStr isEqualToString:[iq fromStr]])
	{
		[self updateLastReceiveTime];
	}
	
	return NO;
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
	if (targetJID == nil || [targetJIDStr isEqualToString:[message fromStr]])
	{
		[self updateLastReceiveTime];
	}
}

- (void)xmppStream:(XMPPStream *)sender didReceivePresence:(XMPPPresence *)presence
{
	if (targetJID == nil || [targetJIDStr isEqualToString:[presence fromStr]])
	{
		[self updateLastReceiveTime];
	}
}

- (void)xmppStreamDidDisconnect:(XMPPStream *)sender
{
	[self stopPingIntervalTimer];
	
	[lastReceiveTime release];
	lastReceiveTime = nil;
	
	awaitingPingResponse = NO;
}

@end
