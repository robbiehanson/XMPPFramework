#import "RosterController.h"
#import "RequestController.h"
#import "XMPPStream.h"
#import "XMPPUser.h"
#import "ChatWindowManager.h"

@interface RosterController (PrivateAPI)

- (BOOL)isRoster:(NSXMLElement *)iq;
- (void)updateRosterWithIQ:(NSXMLElement *)iq;

- (BOOL)isChatMessage:(NSXMLElement *)message;
- (void)handleChatMessage:(NSXMLElement *)message;

- (BOOL)isBuddyRequest:(NSXMLElement *)presence;
- (void)handleBuddyRequest:(NSXMLElement *)presence;
- (void)updateRosterWithPresence:(NSXMLElement *)presence;

@end


@implementation RosterController

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Setup:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (id)init
{
	if(self = [super init])
	{
		xmppStream = [[XMPPStream alloc] init];
		[xmppStream setDelegate:self];
		
		roster = [[NSMutableDictionary alloc] initWithCapacity:5];
		rosterKeys = [[NSArray alloc] init];
	}
	return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// Display the sign in sheet
	[NSApp beginSheet:signInSheet
	   modalForWindow:window
		modalDelegate:self
	   didEndSelector:nil
		  contextInfo:nil];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Account Management:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)updateAccountInfo
{
	[xmpp_hostname release];  xmpp_hostname  = nil;
	[xmpp_username release];  xmpp_username  = nil;
	[xmpp_vhostname release]; xmpp_vhostname = nil;
	[xmpp_password release];  xmpp_password  = nil;
	[xmpp_resource release];  xmpp_resource  = nil;
	
	xmpp_hostname = [[serverField stringValue] copy];
	if([xmpp_hostname length] == 0)
	{
		[xmpp_hostname release];
		xmpp_hostname = [[serverField placeholderString] copy];
	}
	
	xmpp_port = [portField intValue];
	
	usesSSL = ([sslButton state] == NSOnState);
	allowsSelfSignedCertificates = ([selfSignedButton state] == NSOnState);
	
	NSArray *components = [[jidField stringValue] componentsSeparatedByString:@"@"];
	xmpp_username  = [[components objectAtIndex:0] copy];
	xmpp_vhostname = [[components objectAtIndex:1] copy];
	
	xmpp_password = [[passwordField stringValue] copy];
	
	xmpp_resource = [[resourceField stringValue] copy];
	if([xmpp_resource length] == 0)
	{
		[xmpp_resource release];
		xmpp_resource = (NSString *)SCDynamicStoreCopyComputerName(NULL, NULL);
	}
}

- (IBAction)signIn:(id)sender
{
	// Update our variables from the form
	[self updateAccountInfo];
	
	shouldSignIn = YES;
	[signInButton setEnabled:NO];
	[registerButton setEnabled:NO];
	
	if(![xmppStream isConnected])
	{
		[xmppStream setAllowsSelfSignedCertificates:allowsSelfSignedCertificates];
		
		if(usesSSL)
		{
			[xmppStream connectToSecureHost:xmpp_hostname
									 onPort:xmpp_port
							withVirtualHost:xmpp_vhostname];
		}
		else
		{
			[xmppStream connectToHost:xmpp_hostname
							   onPort:xmpp_port
					  withVirtualHost:xmpp_vhostname];
		}
	}
	else
	{
		[xmppStream authenticateUser:xmpp_username
						withPassword:xmpp_password
							resource:xmpp_resource];
	}
}

- (IBAction)createAccount:(id)sender
{
	// Update our variables from the form
	[self updateAccountInfo];
	
	shouldRegister = YES;
	[signInButton setEnabled:NO];
	[registerButton setEnabled:NO];
	
	if(![xmppStream isConnected])
	{
		[xmppStream setAllowsSelfSignedCertificates:allowsSelfSignedCertificates];

		if(usesSSL)
		{
			[xmppStream connectToSecureHost:xmpp_hostname
									 onPort:xmpp_port
							withVirtualHost:xmpp_vhostname];
		}
		else
		{
			[xmppStream connectToHost:xmpp_hostname
							   onPort:xmpp_port
					  withVirtualHost:xmpp_vhostname];
		}
	}
	else
	{
		[xmppStream registerUser:xmpp_username
					withPassword:xmpp_password];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Presence Management:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (IBAction)changePresence:(id)sender
{
	if([[sender titleOfSelectedItem] isEqualToString:@"Offline"])
	{
		NSXMLElement *presence = [NSXMLElement elementWithName:@"presence"];
		[presence addAttribute:[NSXMLNode attributeWithName:@"type" stringValue:@"unavailable"]];
		
		[xmppStream sendElement:presence];
		
		// We don't receive presence notifications when we're unavailable
		// Change the status of all users in roster to unavailable
		// When we become available again, we'll receive every presence notification again
		
		
	}
	else
	{
		NSXMLElement *presence = [NSXMLElement elementWithName:@"presence"];
		
		[xmppStream sendElement:presence];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Buddy Management:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (IBAction)addBuddy:(id)sender
{
	// Get the JID entered by the user
	NSString *jid = [buddyField stringValue];
		
	// Add the buddy to our roster
	NSXMLElement *item = [NSXMLElement elementWithName:@"item"];
	[item addAttribute:[NSXMLNode attributeWithName:@"jid" stringValue:jid]];
	
	NSXMLElement *query = [NSXMLElement elementWithName:@"query"];
	[query addAttribute:[NSXMLNode attributeWithName:@"xmlns" stringValue:@"jabber:iq:roster"]];
	[query addChild:item];
	
	NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
	[iq addAttribute:[NSXMLNode attributeWithName:@"type" stringValue:@"set"]];
	[iq addChild:query];
	
	[xmppStream sendElement:iq];
	
	// Subscribe to the buddy's presence
	NSXMLElement *presence = [NSXMLElement elementWithName:@"presence"];
	[presence addAttribute:[NSXMLNode attributeWithName:@"to" stringValue:jid]];
	[presence addAttribute:[NSXMLNode attributeWithName:@"type" stringValue:@"subscribe"]];
	
	[xmppStream sendElement:presence];
	
	// Clear buddy text field
	[buddyField setStringValue:@""];
}

- (IBAction)removeBuddy:(id)sender
{
	// Get the JID entered by the user
	NSString *jid = [buddyField stringValue];
	
	// Remove the buddy from our roster
	// Unsubscribe from presence
	// And revoke contact's subscription to our presence
	// ...all in one step
	
	NSXMLElement *item = [NSXMLElement elementWithName:@"item"];
	[item addAttribute:[NSXMLNode attributeWithName:@"jid" stringValue:jid]];
	[item addAttribute:[NSXMLNode attributeWithName:@"subscription" stringValue:@"remove"]];
	
	NSXMLElement *query = [NSXMLElement elementWithName:@"query"];
	[query addAttribute:[NSXMLNode attributeWithName:@"xmlns" stringValue:@"jabber:iq:roster"]];
	[query addChild:item];
	
	NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
	[iq addAttribute:[NSXMLNode attributeWithName:@"type" stringValue:@"set"]];
	[iq addChild:query];
	
	[xmppStream sendElement:iq];
	
	// Clear buddy text field
	[buddyField setStringValue:@""];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Messages:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (IBAction)chat:(id)sender
{
	int selectedRow = [rosterTable selectedRow];
	
	if(selectedRow >= 0)
	{
		XMPPUser *user = [roster objectForKey:[rosterKeys objectAtIndex:selectedRow]];
		
		[ChatWindowManager openChatWindowWithXMPPStream:xmppStream forXMPPUser:user];
	}
}

- (XMPPStream *)xmppStream
{
	return xmppStream;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Roster Table Data Source:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [rosterKeys count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)rowIndex
{
	XMPPUser *user = [roster objectForKey:[rosterKeys objectAtIndex:rowIndex]];
	
	if([[tableColumn identifier] isEqualToString:@"name"])
		return [user name];
	else
		return [user jid];
}

- (void)tableView:(NSTableView *)tableView
   setObjectValue:(id)anObject
   forTableColumn:(NSTableColumn *)tableColumn
			  row:(int)rowIndex
{
	XMPPUser *user = [roster objectForKey:[rosterKeys objectAtIndex:rowIndex]];
	NSString *newName = (NSString *)anObject;
	
	NSXMLElement *item = [NSXMLElement elementWithName:@"item"];
	[item addAttribute:[NSXMLNode attributeWithName:@"jid" stringValue:[user jid]]];
	[item addAttribute:[NSXMLNode attributeWithName:@"name" stringValue:newName]];
	
	NSXMLElement *query = [NSXMLElement elementWithName:@"query"];
	[query addAttribute:[NSXMLNode attributeWithName:@"xmlns" stringValue:@"jabber:iq:roster"]];
	[query addChild:item];
	
	NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
	[iq addAttribute:[NSXMLNode attributeWithName:@"type" stringValue:@"set"]];
	[iq addChild:query];
	
	[xmppStream sendElement:iq];
}

- (void)tableView:(NSTableView *)tableView
  willDisplayCell:(id)cell
   forTableColumn:(NSTableColumn *)tableColumn 
			  row:(int)rowIndex
{
	XMPPUser *user = [roster objectForKey:[rosterKeys objectAtIndex:rowIndex]];
	
	BOOL isRowSelected = ([tableView isRowSelected:rowIndex]);
	BOOL isFirstResponder = [[[tableView window] firstResponder] isEqual:tableView];
	BOOL isKeyWindow = [[tableView window] isKeyWindow];
	BOOL isApplicationActive = [NSApp isActive];
	
	BOOL isRowHighlighted = (isRowSelected && isFirstResponder && isKeyWindow && isApplicationActive);
	
	if([user isOnline])
	{
		[cell setTextColor:[NSColor blackColor]];
	}
	else
	{
		NSColor *grayColor;
		if(isRowHighlighted)
			grayColor = [NSColor colorWithCalibratedRed:(184/255.0) green:(175/255.0) blue:(184/255.0) alpha:1.0];
		else
			grayColor = [NSColor colorWithCalibratedRed:(134/255.0) green:(125/255.0) blue:(134/255.0) alpha:1.0];
			
		[cell setTextColor:grayColor];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStream Delegate Methods:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppStreamDidOpen:(XMPPStream *)xs
{
	if(shouldSignIn)
	{
		[xmppStream authenticateUser:xmpp_username
						withPassword:xmpp_password
							resource:xmpp_resource];
	}
	else if(shouldRegister)
	{
		[xmppStream registerUser:xmpp_username
					withPassword:xmpp_password];
	}
}

- (void)xmppStreamDidRegister:(XMPPStream *)xs
{
	// Update tracking variables
	shouldRegister = NO;
	
	// Update GUI
	[signInButton setEnabled:YES];
	[registerButton setEnabled:YES];
	[messageField setStringValue:@"Registered new user"];
}

- (void)xmppStreamDidAuthenticate:(XMPPStream *)xs
{
	// Update tracking variables
	shouldSignIn = NO;
	
	// Close the sheet
	[signInSheet orderOut:self];
	[NSApp endSheet:signInSheet];
	
	// Fetch roster
	NSXMLElement *query = [NSXMLElement elementWithName:@"query"];
	[query addAttribute:[NSXMLNode attributeWithName:@"xmlns" stringValue:@"jabber:iq:roster"]];
	
	NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
	[iq addAttribute:[NSXMLNode attributeWithName:@"type" stringValue:@"get"]];
	[iq addChild:query];
	
	[xmppStream sendElement:iq];
}

- (void)xmppStream:(XMPPStream *)xs didReceiveError:(id)error
{
	if(shouldSignIn)
	{
		// Update tracking variables
		shouldSignIn = NO;
		
		// Update GUI
		[signInButton setEnabled:YES];
		[registerButton setEnabled:YES];
		[messageField setStringValue:@"Invalid username/password"];
	}
	else if(shouldRegister)
	{
		// Update tracking variables
		shouldRegister = NO;
		
		// Update GUI
		[signInButton setEnabled:YES];
		[registerButton setEnabled:YES];
		[messageField setStringValue:@"Username is taken"];
	}
	else
	{
		NSLog(@"--- Unknown Error ---");
	}
}

- (void)xmppStream:(XMPPStream *)xs didReceiveIQ:(NSXMLElement *)iq
{
	if([self isRoster:iq])
	{
		[self updateRosterWithIQ:iq];
	}
	else
	{
		NSLog(@"--- Unknown IQ ---");
	}
}

- (void)xmppStream:(XMPPStream *)xs didReceiveMessage:(NSXMLElement *)message
{
	if([self isChatMessage:message])
	{
		[self handleChatMessage:message];
	}
	else
	{
		NSLog(@"--- Unknown Message ---");
	}
}

- (void)xmppStream:(XMPPStream *)xs didReceivePresence:(NSXMLElement *)presence
{
	if([self isBuddyRequest:presence])
	{
		[self handleBuddyRequest:presence];
	}
	else
	{
		[self updateRosterWithPresence:presence];
	}
}

- (void)xmppStreamDidClose:(XMPPStream *)xs
{
	// Clear our roster
	[roster removeAllObjects];
	[rosterKeys release];
	rosterKeys = [[NSArray alloc] init];
	
	// Display the sign in sheet
	[NSApp beginSheet:signInSheet
	   modalForWindow:window
		modalDelegate:self
	   didEndSelector:nil
		  contextInfo:nil];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Private API - IQ:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Returns whether or not the given IQ element is in the "jabber:iq:roster" namespace,
 * and thus represents a roster update.
**/
- (BOOL)isRoster:(NSXMLElement *)iq
{
	NSXMLElement *query = [iq elementForName:@"query"];
	return [[query xmlns] isEqualToString:@"jabber:iq:roster"];
}

/**
 * For some bizarre reason (in my opinion), when you request your roster,
 * the server will return JID's NOT in your roster. These are the JID's of users who have requested
 * to be alerted to our presence.  After we sign in, we'll again be notified, via the normal presence request objects.
 * It's redundant, and annoying, and just plain incorrect to include these JID's when we request our personal roster.
 * So now, we have to go to the extra effort to filter out these JID's, which is exactly what this method does.
 *
 * Someone please correct me if I'm wrong about this.
**/
- (BOOL)isRosterItem:(NSXMLElement *)item
{
	NSXMLNode *subscription = [item attributeForName:@"subscription"];
	if([[subscription stringValue] isEqualToString:@"none"])
	{
		NSXMLNode *ask = [item attributeForName:@"ask"];
		if([[ask stringValue] isEqualToString:@"subscribe"]) {
			return YES;
		}
		else {
			return NO;
		}
	}
	return YES;
}

/**
 * Given a roster IQ element, this method updates the roster accordingly for any included users.
 * This method assumes the IQ element is a proper roster element. This can be tested using the isRoster: method.
**/
- (void)updateRosterWithIQ:(NSXMLElement *)iq
{
	NSArray *items = [[iq elementForName:@"query"] elementsForName:@"item"];
	
	int i;
	for(i = 0; i < [items count]; i++)
	{
		NSXMLElement *item = (NSXMLElement *)[items objectAtIndex:i];
		
		// Filter out presence requests. We just want to get our roster. (Like we requested...)
		if([self isRosterItem:item])
		{
			NSString *jidKey = [[[item attributeForName:@"jid"] stringValue] lowercaseString];
				
			XMPPUser *user = [roster objectForKey:jidKey];
			if(user)
				[user updateWithItem:item];
			else
			{
				user = [[[XMPPUser alloc] initWithItem:item] autorelease];
				[roster setObject:user forKey:jidKey];
			}
		}
	}
	
	[rosterKeys release];
	rosterKeys = [[roster keysSortedByValueUsingSelector:@selector(compareByAvailabilityName:)] retain];
	
	[rosterTable abortEditing];
	[rosterTable selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:NO];
	[rosterTable reloadData];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Private API - Message:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)isChatMessage:(NSXMLElement *)message
{
	return [[[message attributeForName:@"type"] stringValue] isEqualToString:@"chat"];
}

- (void)handleChatMessage:(NSXMLElement *)message
{
	// Get the JID from the message
	NSString *jidAndResource = [[message attributeForName:@"from"] stringValue];
	NSString *jid = [[jidAndResource componentsSeparatedByString:@"/"] objectAtIndex:0];
	
	// JID's are case insensitive, so the keys in the dictionary are used accordingly
	NSString *jidKey = [jid lowercaseString];
	
	// Get the corresponding XMPPUser
	XMPPUser *user = [roster objectForKey:jidKey];
	
	[ChatWindowManager handleChatMessage:message withXMPPStream:xmppStream fromXMPPUser:user];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Private API - Presence:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Returns whether or not the given presence element is a request from another user to be added as a buddy.
**/
- (BOOL)isBuddyRequest:(NSXMLElement *)presence
{
	return [[[presence attributeForName:@"type"] stringValue] isEqualToString:@"subscribe"];
}

- (void)handleBuddyRequest:(NSXMLElement *)presence
{
	// Get the JID of the user requesting friendship
	NSString *jidAndResource = [[presence attributeForName:@"from"] stringValue];
	NSString *jid = [[jidAndResource componentsSeparatedByString:@"/"] objectAtIndex:0];
	
	// JID's are case insensitive, so the keys in the dictionary are used accordingly
	NSString *jidKey = [jid lowercaseString];
	
	// If we already requested friendship with the user, automatically accept the request
	if([roster objectForKey:jidKey])
	{
		NSXMLElement *response = [NSXMLElement elementWithName:@"presence"];
		[response addAttribute:[NSXMLNode attributeWithName:@"to" stringValue:jid]];
		[response addAttribute:[NSXMLNode attributeWithName:@"type" stringValue:@"subscribed"]];
		
		[xmppStream sendElement:response];
	}
	else
	{
		// The request controller will handle displaying a message
		[requestController handleBuddyRequest:jid];
	}
}

- (void)updateRosterWithPresence:(NSXMLElement *)presence
{
	// Get the JID of the user updating presence
	NSString *jidAndResource = [[presence attributeForName:@"from"] stringValue];
	NSString *jid = [[jidAndResource componentsSeparatedByString:@"/"] objectAtIndex:0];
	
	// JID's are case insensitive, so the keys in the dictionary are used accordingly
	NSString *jidKey = [jid lowercaseString];
	
	XMPPUser *user = [roster objectForKey:jidKey];
	[user updateWithPresence:presence];
	
	[rosterKeys release];
	rosterKeys = [[roster keysSortedByValueUsingSelector:@selector(compareByAvailabilityName:)] retain];
	
	[rosterTable abortEditing];
	[rosterTable selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:NO];
	[rosterTable reloadData];
}

@end
