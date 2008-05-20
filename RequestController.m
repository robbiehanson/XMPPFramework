#import "RequestController.h"
#import "RosterController.h"
#import "XMPP.h"


@implementation RequestController

- (id)init
{
	if(self = [super init])
	{
		jids = [[NSMutableArray alloc] init];
		jidIndex = -1;
	}
	return self;
}

- (void)awakeFromNib
{
	[xmppClient addDelegate:self];
	
	NSRect visibleFrame = [[window screen] visibleFrame];
	NSRect windowFrame = [window frame];
	
	NSPoint windowPosition;
	windowPosition.x = visibleFrame.origin.x + visibleFrame.size.width - windowFrame.size.width - 5;
	windowPosition.y = visibleFrame.origin.y + visibleFrame.size.height - windowFrame.size.height - 5;
	
	[window setFrameOrigin:windowPosition];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[jids release];
	[super dealloc];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Helper Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)nextRequest
{
	if(++jidIndex < [jids count])
	{
		XMPPJID *jid = [jids objectAtIndex:jidIndex];
		
		[jidField setStringValue:[jid bare]];
		[xofyField setStringValue:[NSString stringWithFormat:@"%i of %i", (jidIndex+1), [jids count]]];
	}
	else
	{
		[jids removeAllObjects];
		jidIndex = -1;
		[window close];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// XMPPClient Delegate Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppClient:(XMPPClient *)sender didReceiveBuddyRequest:(XMPPJID *)jid
{
	if(![jids containsObject:jid])
	{
		[jids addObject:jid];
		
		if([jids count] == 1)
		{
			jidIndex = 0;
			
			[jidField setStringValue:[jid bare]];
			[xofyField setHidden:YES];
			
			[window setAlphaValue:0.85];
			[window makeKeyAndOrderFront:self];
		}
		else
		{
			[xofyField setStringValue:[NSString stringWithFormat:@"%i of %i", (jidIndex+1), [jids count]]];
			[xofyField setHidden:NO];
		}
	}
}

- (void)xmppClientDidUpdateRoster:(XMPPClient *)sender
{
	// Often times XMPP servers send presence requests prior to sending the roster.
	// That is, after you authenticate, they immediately send you presence requests,
	// meaning that we receive them before we've had a chance to request and receive our roster.
	// The result is that we may not know, upon receiving a presence request,
	// if we've already requested this person to be our buddy.
	// We make up for that by fixing our mistake as soon as possible.
	
	NSArray *roster = [xmppClient sortedUsersByAvailabilityName];
	
	int i;
	for(i = 0; i < [roster count]; i++)
	{
		XMPPUser *user = [roster objectAtIndex:i];
		
		int index = [jids indexOfObject:[user jid]];
		
		if(index != NSNotFound)
		{
			[xmppClient acceptBuddyRequest:[user jid]];
			
			[jids removeObjectAtIndex:index];
			
			// Call nextRequest, but we don't actually want to increment jidIndex
			jidIndex--;
			[self nextRequest];
		}
	}
}

- (void)xmppClientDidDisconnect:(XMPPClient *)sender
{
	// We can't accept or reject any requests when we're disconnected from the server.
	// We may as well close the window.
	
	[jids removeAllObjects];
	jidIndex = -1;
	[window close];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Interface Builder Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (IBAction)accept:(id)sender
{
	XMPPJID *jid = [jids objectAtIndex:jidIndex];
	[xmppClient acceptBuddyRequest:jid];
	
	[self nextRequest];
}

- (IBAction)reject:(id)sender
{
	XMPPJID *jid = [jids objectAtIndex:jidIndex];
	[xmppClient rejectBuddyRequest:jid];
	
	[self nextRequest];
}

@end
