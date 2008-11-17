#import "RosterController.h"
#import "RequestController.h"
#import "XMPP.h"
#import "ChatWindowManager.h"
#import <SystemConfiguration/SystemConfiguration.h>


@implementation RosterController

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Setup:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (id)init
{
	if(self = [super init])
	{
		// Nothing to do here
	}
	return self;
}

- (void)awakeFromNib
{
	[xmppClient addDelegate:self];
	[xmppClient setAutoLogin:NO];
	[xmppClient setAutoRoster:YES];
	[xmppClient setAutoPresence:YES];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// Display the sign in sheet
	NSUserDefaults *dflts = [NSUserDefaults standardUserDefaults];
	[serverField setObjectValue:[dflts objectForKey:@"Account.Server"]];
	[resourceField setObjectValue:[dflts objectForKey:@"Account.Resource"]];
	[portField setObjectValue:[dflts objectForKey:@"Account.Port"]];
	[jidField setObjectValue:[dflts objectForKey:@"Account.JID"]];
	[sslButton setObjectValue:[dflts objectForKey:@"Account.UseSSL"]];
	[selfSignedButton setObjectValue:[dflts objectForKey:@"Account.AllowSelfSignedCert"]];

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
	NSString *domain = [serverField stringValue];
	if([domain length] == 0)
	{
		domain = [[serverField cell] placeholderString];
	}
	[xmppClient setDomain:domain];
	
	int port = [portField intValue];
	[xmppClient setPort:port];
	
	BOOL usesSSL = ([sslButton state] == NSOnState);
	BOOL allowsSelfSignedCertificates = ([selfSignedButton state] == NSOnState);
	
	[xmppClient setUsesOldStyleSSL:usesSSL];
	[xmppClient setAllowsSelfSignedCertificates:allowsSelfSignedCertificates];
	
	NSString *resource = [resourceField stringValue];
	if([resource length] == 0)
	{
		resource = [(NSString *)SCDynamicStoreCopyComputerName(NULL, NULL) autorelease];
	}
	
	XMPPJID *jid = [XMPPJID jidWithString:[jidField stringValue] resource:resource];
	
	[xmppClient setMyJID:jid];
	
	[xmppClient setPassword:[passwordField stringValue]];
    
	// Update persistent defaults:
	NSUserDefaults *dflts = [NSUserDefaults standardUserDefaults];
	[dflts setObject:domain forKey:@"Account.Server"];
	[dflts setObject:[resourceField stringValue]
			  forKey:@"Account.Resource"];
	[dflts setObject:(port ? [NSNumber numberWithInt:port] : nil)
			  forKey:@"Account.Port"];
	[dflts setObject:[jidField stringValue]
			  forKey:@"Account.JID"];
	[dflts setBool:usesSSL 
			forKey:@"Account.UseSSL"];
	[dflts setBool:allowsSelfSignedCertificates 
			forKey:@"Account.AllowSelfSignedCert"];
	[dflts synchronize];
}

- (IBAction)createAccount:(id)sender
{
	[self updateAccountInfo];
	
	isRegistering = YES;
	[signInButton setEnabled:NO];
	[registerButton setEnabled:NO];
	
	if(![xmppClient isConnected])
	{
		[xmppClient connect];
	}
	else
	{
		[xmppClient registerUser];
	}
}

- (IBAction)signIn:(id)sender
{
	[self updateAccountInfo];
	
	isAuthenticating = YES;
	[signInButton setEnabled:NO];
	[registerButton setEnabled:NO];
	
	if(![xmppClient isConnected])
	{
		[xmppClient connect];
	}
	else
	{
		[xmppClient authenticateUser];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Presence Management:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (IBAction)changePresence:(id)sender
{
	if([[sender titleOfSelectedItem] isEqualToString:@"Offline"])
	{
		[xmppClient goOffline];
	}
	else
	{
		[xmppClient goOnline];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Buddy Management:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (IBAction)addBuddy:(id)sender
{
	XMPPJID *jid = [XMPPJID jidWithString:[buddyField stringValue]];
	
	[xmppClient addBuddy:jid withNickname:nil];
	
	// Clear buddy text field
	[buddyField setStringValue:@""];
}

- (IBAction)removeBuddy:(id)sender
{
	XMPPJID *jid = [XMPPJID jidWithString:[buddyField stringValue]];
	
	[xmppClient removeBuddy:jid];
	
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
		XMPPUser *user = [roster objectAtIndex:selectedRow];
		
		[ChatWindowManager openChatWindowWithXMPPClient:xmppClient forXMPPUser:user];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Roster Table Data Source:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [roster count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)rowIndex
{
	XMPPUser *user = [roster objectAtIndex:rowIndex];
	
	if([[tableColumn identifier] isEqualToString:@"name"])
		return [user nickname];
	else
		return [user jid];
	
	return nil;
}

- (void)tableView:(NSTableView *)tableView
   setObjectValue:(id)anObject
   forTableColumn:(NSTableColumn *)tableColumn
			  row:(int)rowIndex
{
	XMPPUser *user = [roster objectAtIndex:rowIndex];
	NSString *newName = (NSString *)anObject;
	
	[xmppClient setNickname:newName forBuddy:[user jid]];
}

- (void)tableView:(NSTableView *)tableView
  willDisplayCell:(id)cell
   forTableColumn:(NSTableColumn *)tableColumn 
			  row:(int)rowIndex
{
	XMPPUser *user = [roster objectAtIndex:rowIndex];
	
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
#pragma mark XMPPClient Delegate Methods:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppClientDidConnect:(XMPPClient *)sender
{
	if(isRegistering)
		[xmppClient registerUser];
	else
		[xmppClient authenticateUser];
}

- (void)xmppClientDidNotConnect:(XMPPClient *)sender
{
	NSLog(@"---------- xmppClientDidNotConnect ----------");
	if([sender streamError])
	{
		NSLog(@"           error: %@", [sender streamError]);
	}
	
	// Update tracking variables
	isRegistering = NO;
	isAuthenticating = NO;
	
	// Update GUI
	[signInButton setEnabled:YES];
	[registerButton setEnabled:YES];
	[messageField setStringValue:@"Cannot connect to server"];
}

- (void)xmppClientDidDisconnect:(XMPPClient *)sender
{
	NSLog(@"---------- xmppClientDidDisconnect ----------");
	if ([sender streamError])
	{
		NSLog(@"           error: %@", [sender streamError]);
	}
	
	[signInButton setEnabled:YES];
	[registerButton setEnabled:YES];
	[messageField setStringValue:@"Unexpectedly disconnected from server"];
}

- (void)xmppClientDidRegister:(XMPPClient *)sender
{
	// Update tracking variables
	isRegistering = NO;
	
	// Update GUI
	[signInButton setEnabled:YES];
	[registerButton setEnabled:YES];
	[messageField setStringValue:@"Registered new user"];
}

- (void)xmppClient:(XMPPClient *)sender didNotRegister:(NSXMLElement *)error
{
	// Update tracking variables
	isRegistering = NO;
	
	// Update GUI
	[signInButton setEnabled:YES];
	[registerButton setEnabled:YES];
	[messageField setStringValue:@"Username is taken"];
}

- (void)xmppClientDidAuthenticate:(XMPPClient *)sender
{
	// Update tracking variables
	isAuthenticating = NO;
	
	// Close the sheet
	[signInSheet orderOut:self];
	[NSApp endSheet:signInSheet];
}

- (void)xmppClient:(XMPPClient *)sender didNotAuthenticate:(NSXMLElement *)error
{
	// Update tracking variables
	isAuthenticating = NO;
	
	// Update GUI
	[signInButton setEnabled:YES];
	[registerButton setEnabled:YES];
	[messageField setStringValue:@"Invalid username/password"];
}

- (void)xmppClientDidUpdateRoster:(XMPPClient *)sender
{
	[roster release];
	roster = [[xmppClient sortedUsersByAvailabilityName] retain];
	
	[rosterTable abortEditing];
	[rosterTable selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:NO];
	[rosterTable reloadData];
}

- (void)xmppClient:(XMPPClient *)sender didReceiveIQ:(XMPPIQ *)iq
{
	NSLog(@"---------- xmppClient:didReceiveIQ: ----------");
}

- (void)xmppClient:(XMPPClient *)sender didReceiveMessage:(XMPPMessage *)message
{
	if([message isChatMessageWithBody])
	{
		[ChatWindowManager handleChatMessage:message withXMPPClient:xmppClient];
	}
}

@end
