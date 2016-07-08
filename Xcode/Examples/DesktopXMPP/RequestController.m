#import "RequestController.h"
#import "RosterController.h"
#import "AppDelegate.h"


@implementation RequestController

- (id)init
{
	if((self = [super init]))
	{
		jids = [[NSMutableArray alloc] init];
		jidIndex = -1;
	}
	return self;
}

- (XMPPStream *)xmppStream
{
	return [(AppDelegate *)[NSApp delegate] xmppStream];
}

- (XMPPRoster *)xmppRoster
{
	return [(AppDelegate *)[NSApp delegate] xmppRoster];
}

- (void)awakeFromNib
{
	[[self xmppStream] addDelegate:self delegateQueue:dispatch_get_main_queue()];
	[[self xmppRoster] addDelegate:self delegateQueue:dispatch_get_main_queue()];
	
	NSRect visibleFrame = [[window screen] visibleFrame];
	NSRect windowFrame = [window frame];
	
	NSPoint windowPosition;
	windowPosition.x = visibleFrame.origin.x + visibleFrame.size.width - windowFrame.size.width - 5;
	windowPosition.y = visibleFrame.origin.y + visibleFrame.size.height - windowFrame.size.height - 5;
	
	[window setFrameOrigin:windowPosition];
}

- (void)dealloc
{
	[[self xmppStream] removeDelegate:self];
	[[self xmppRoster] removeDelegate:self];
	
	
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// NSWindow Delegate Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)windowWillClose:(NSNotification *)notification
{
	// User chose to ignore requests by closing the window
	
	[jids removeAllObjects];
	jidIndex = -1;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Helper Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)nextRequest
{
	NSLog(@"RequestController: nextRequest");
	
	if(++jidIndex < [jids count])
	{
		XMPPJID *jid = [jids objectAtIndex:jidIndex];
		
		[jidField setStringValue:[jid bare]];
		[xofyField setStringValue:[NSString stringWithFormat:@"%i of %i", (jidIndex+1), (int)[jids count]]];
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

- (void)xmppRoster:(XMPPRoster *)sender didReceiveBuddyRequest:(XMPPPresence *)presence
{
	XMPPJID *jid = [presence from];
	
	if(![jids containsObject:jid])
	{
		[jids addObject:jid];
		
		if([jids count] == 1)
		{
			jidIndex = 0;
			
			[jidField setStringValue:[jid bare]];
			[xofyField setHidden:YES];
			
			[window setAlphaValue:0.85F];
			[window makeKeyAndOrderFront:self];
		}
		else
		{
			[xofyField setStringValue:[NSString stringWithFormat:@"%i of %i", (jidIndex+1), (int)[jids count]]];
			[xofyField setHidden:NO];
		}
	}
}

- (void)xmppRosterDidChange:(XMPPRosterMemoryStorage *)sender
{
	// Often times XMPP servers send presence requests prior to sending the roster.
	// That is, after you authenticate, they immediately send you presence requests,
	// meaning that we receive them before we've had a chance to request and receive our roster.
	// The result is that we may not know, upon receiving a presence request,
	// if we've already requested this person to be our buddy.
	// We make up for that by fixing our mistake as soon as possible.
	
	NSArray *roster = [sender sortedUsersByAvailabilityName];
	
	// Remember: Our roster contains only those users we've added.
	// If the server tries to include buddies that we haven't added, but have asked to subscribe to us,
	// the xmpp client filters them out.
	
	NSUInteger i;
	for(i = 0; i < [roster count]; i++)
	{
		id <XMPPUser> user = [roster objectAtIndex:i];
		
		NSUInteger currentIndex = [jids indexOfObject:[user jid]];
		
		if(currentIndex != NSNotFound)
		{
			// Now we may be getting a notification of an updated roster due to an accept/reject we just sent.
			// The simplest way to check is if the index isn't pointing to a jid we've already processed.
			
			if(currentIndex >= jidIndex)
			{
				NSLog(@"Auto-accepting buddy request, since they already accepted us");
				
				[[self xmppRoster] acceptPresenceSubscriptionRequestFrom:[user jid] andAddToRoster:YES];
			
				[jids removeObjectAtIndex:currentIndex];
				
				// We need to calll nextRequest, but we want jidIndex to remain at it's current jid
				if(currentIndex >= jidIndex)
				{
					// Subtract 1, because nextRequest will immediately add 1
					jidIndex = jidIndex - 1;
				}
				else
				{
					// Subtract 2, because the current jid will go down 1
					// and because nextRequest will immediately add 1
					jidIndex = jidIndex - 2;
				}
				
				[self nextRequest];
			}
		}
	}
}

- (void)xmppStreamDidDisconnect:(XMPPStream *)sender withError:(NSError *)error
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
	
	[[self xmppRoster] acceptPresenceSubscriptionRequestFrom:jid andAddToRoster:YES];
	
	[self nextRequest];
}

- (IBAction)reject:(id)sender
{
	XMPPJID *jid = [jids objectAtIndex:jidIndex];
	
	[[self xmppRoster] rejectPresenceSubscriptionRequestFrom:jid];
	
	[self nextRequest];
}

@end
