#import "RequestController.h"
#import "RosterController.h"
#import "XMPPStream.h"

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
#pragma mark Implementation
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)handleBuddyRequest:(NSString *)jid
{
	if(![jids containsObject:jid])
	{
		[jids addObject:jid];
		
		if([jids count] == 1)
		{
			jidIndex = 0;
			
			[jidField setStringValue:jid];
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

- (void)nextRequest
{
	if(++jidIndex < [jids count])
	{
		[jidField setStringValue:[jids objectAtIndex:jidIndex]];
		[xofyField setStringValue:[NSString stringWithFormat:@"%i of %i", (jidIndex+1), [jids count]]];
	}
	else
	{
		[jids removeAllObjects];
		jidIndex = -1;
		[window close];
	}
}

- (IBAction)accept:(id)sender
{
	NSString *jid = [jids objectAtIndex:jidIndex];
	
	// Send presence response
	NSXMLElement *response = [NSXMLElement elementWithName:@"presence"];
	[response addAttribute:[NSXMLNode attributeWithName:@"to" stringValue:jid]];
	[response addAttribute:[NSXMLNode attributeWithName:@"type" stringValue:@"subscribed"]];
	
	[[rosterController xmppStream] sendElement:response];
	
	// Add user to our roster
	NSXMLElement *item = [NSXMLElement elementWithName:@"item"];
	[item addAttribute:[NSXMLNode attributeWithName:@"jid" stringValue:jid]];
	
	NSXMLElement *query = [NSXMLElement elementWithName:@"query"];
	[query addAttribute:[NSXMLNode attributeWithName:@"xmlns" stringValue:@"jabber:iq:roster"]];
	[query addChild:item];
	
	NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
	[iq addAttribute:[NSXMLNode attributeWithName:@"type" stringValue:@"set"]];
	[iq addChild:query];
	
	[[rosterController xmppStream] sendElement:iq];
	
	// Subscribe to the user's presence
	NSXMLElement *presence = [NSXMLElement elementWithName:@"presence"];
	[presence addAttribute:[NSXMLNode attributeWithName:@"to" stringValue:jid]];
	[presence addAttribute:[NSXMLNode attributeWithName:@"type" stringValue:@"subscribe"]];
	
	[[rosterController xmppStream] sendElement:presence];
	
	// Process the next request
	[self nextRequest];
}

- (IBAction)reject:(id)sender
{
	NSString *jid = [jids objectAtIndex:jidIndex];
	
	// Send presence response
	NSXMLElement *response = [NSXMLElement elementWithName:@"presence"];
	[response addAttribute:[NSXMLNode attributeWithName:@"to" stringValue:jid]];
	[response addAttribute:[NSXMLNode attributeWithName:@"type" stringValue:@"unsubscribed"]];
	
	[[rosterController xmppStream] sendElement:response];
	
	// Process the next request
	[self nextRequest];
}

@end
