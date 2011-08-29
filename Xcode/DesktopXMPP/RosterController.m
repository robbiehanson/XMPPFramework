#import "RosterController.h"
#import "RequestController.h"
#import "ChatWindowManager.h"
#import "AppDelegate.h"
#import "DDLog.h"

#import <SystemConfiguration/SystemConfiguration.h>

// Log levels: off, error, warn, info, verbose
static const int ddLogLevel = LOG_LEVEL_VERBOSE;


@implementation RosterController

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Setup:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (XMPPStream *)xmppStream
{
	return [[NSApp delegate] xmppStream];
}

- (XMPPRoster *)xmppRoster
{
	return [[NSApp delegate] xmppRoster];
}

- (XMPPRosterMemoryStorage *)xmppRosterStorage
{
	return [[NSApp delegate] xmppRosterStorage];
}

- (void)awakeFromNib
{
	DDLogInfo(@"%@: %@", THIS_FILE, THIS_METHOD);
	
	[[self xmppRoster] setAutoFetchRoster:YES];
	[[self xmppRoster] setAutoAcceptKnownPresenceSubscriptionRequests:YES];
	
	[[self xmppStream] addDelegate:self delegateQueue:dispatch_get_main_queue()];
	[[self xmppRoster] addDelegate:self delegateQueue:dispatch_get_main_queue()];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Sign In Sheet
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)displaySignInSheet
{
	NSUserDefaults *dflts = [NSUserDefaults standardUserDefaults];
	
	[serverField      setObjectValue:[dflts objectForKey:@"Account.Server"]];
	[resourceField    setObjectValue:[dflts objectForKey:@"Account.Resource"]];
	[portField        setObjectValue:[dflts objectForKey:@"Account.Port"]];
	[jidField         setObjectValue:[dflts objectForKey:@"Account.JID"]];
	[sslButton        setObjectValue:[dflts objectForKey:@"Account.UseSSL"]];
	[selfSignedButton setObjectValue:[dflts objectForKey:@"Account.AllowSelfSignedCert"]];
	[mismatchButton   setObjectValue:[dflts objectForKey:@"Account.AllowSSLHostNameMismatch"]];
	
	[NSApp beginSheet:signInSheet
	   modalForWindow:window
	    modalDelegate:self
	   didEndSelector:nil
	      contextInfo:nil];
	
	if ([[portField stringValue] length] > 0)
	{
		if ([[jidField stringValue] length] > 0)
		{
			[signInSheet makeFirstResponder:passwordField];
		}
		else
		{
			[signInSheet makeFirstResponder:jidField];
		}
	}
	else
	{
		if ([[serverField stringValue] length] > 0)
		{
			[signInSheet makeFirstResponder:portField];
		}
	}
	
	[self jidDidChange:nil];
}

- (IBAction)jidDidChange:(id)sender
{
	NSString *jidStr = [jidField stringValue];
	
	if ([jidStr length] > 0)
	{
		NSString *domain = [serverField stringValue];
		
		if ([jidStr rangeOfString:@"@"].location == NSNotFound)
		{
			// People often forget to type in the full JID.
			// In other words, they type in "username" instead of "username@domain.tld"
			// 
			// So we automatically append a domain to the JID.
			
			if ([domain length] > 0)
			{
				[jidField setStringValue:[jidStr stringByAppendingFormat:@"@%@", domain]];
			}
		}
		else if ([domain length] == 0)
		{
			// Update the domain placeholder string to match the JID domain
			
			XMPPJID *jid = [XMPPJID jidWithString:jidStr];
			if (jid)
			{
				[[serverField cell] setPlaceholderString:[jid domain]];
			}
		}
	}
}

- (void)enableSignInUI:(BOOL)enabled
{
	[serverField setEnabled:enabled];
	[portField setEnabled:enabled];
	
	[sslButton setEnabled:enabled];
	[selfSignedButton setEnabled:enabled];
	[mismatchButton setEnabled:enabled];
	
	[jidField setEnabled:enabled];
	[passwordField setEnabled:enabled];
	
	[resourceField setEnabled:enabled];
	
	[signInButton setEnabled:enabled];
	[registerButton setEnabled:enabled];
}

- (void)lockSignInUI
{
	[self enableSignInUI:NO];
}

- (void)unlockSignInUI
{
	[self enableSignInUI:YES];
}

- (void)updateAccountInfo
{
	NSString *domain = [serverField stringValue];
	[[self xmppStream] setHostName:domain];
	
	int port = [portField intValue];
	[[self xmppStream] setHostPort:port];
	
	useSSL = ([sslButton state] == NSOnState);
	allowSelfSignedCertificates = ([selfSignedButton state] == NSOnState);
	allowSSLHostNameMismatch = ([mismatchButton state] == NSOnState);
	
	NSString *resource = [resourceField stringValue];
	if([resource length] == 0)
	{
		resource = [(NSString *)SCDynamicStoreCopyComputerName(NULL, NULL) autorelease];
	}
	
	XMPPJID *jid = [XMPPJID jidWithString:[jidField stringValue] resource:resource];
	
	[[self xmppStream] setMyJID:jid];
    
	// Update persistent defaults:
	NSUserDefaults *dflts = [NSUserDefaults standardUserDefaults];
	[dflts setObject:domain forKey:@"Account.Server"];
	[dflts setObject:[resourceField stringValue]
			  forKey:@"Account.Resource"];
	[dflts setObject:(port ? [NSNumber numberWithInt:port] : nil)
			  forKey:@"Account.Port"];
	[dflts setObject:[jidField stringValue]
			  forKey:@"Account.JID"];
	[dflts setBool:useSSL 
			forKey:@"Account.UseSSL"];
	[dflts setBool:allowSelfSignedCertificates 
			forKey:@"Account.AllowSelfSignedCert"];
	[dflts setBool:allowSSLHostNameMismatch 
			forKey:@"Account.AllowSSLHostNameMismatch"];
	[dflts synchronize];
}

- (IBAction)createAccount:(id)sender
{
	[self updateAccountInfo];
	
	NSError *error = nil;
	BOOL success;
	
	if(![[self xmppStream] isConnected])
	{
		if (useSSL)
			success = [[self xmppStream] oldSchoolSecureConnect:&error];
		else
			success = [[self xmppStream] connect:&error];
	}
	else
	{
		NSString *password = [passwordField stringValue];
		
		success = [[self xmppStream] registerWithPassword:password error:&error];
	}
	
	if (success)
	{
		isRegistering = YES;
		[self lockSignInUI];
	}
	else
	{
		[messageField setStringValue:[error localizedDescription]];
	}
}

- (IBAction)signIn:(id)sender
{
	[self updateAccountInfo];
	
	NSError *error = nil;
	BOOL success;
	
	if(![[self xmppStream] isConnected])
	{
		if (useSSL)
			success = [[self xmppStream] oldSchoolSecureConnect:&error];
		else
			success = [[self xmppStream] connect:&error];
	}
	else
	{
		NSString *password = [passwordField stringValue];
		
		success = [[self xmppStream] authenticateWithPassword:password error:&error];
	}
	
	if (success)
	{
		isAuthenticating = YES;
		[self lockSignInUI];
	}
	else
	{
		[messageField setStringValue:[error localizedDescription]];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Presence Management
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)goOnline
{
	NSXMLElement *presence = [NSXMLElement elementWithName:@"presence"];
	
	[[self xmppStream] sendElement:presence];
}

- (void)goOffline
{
	NSXMLElement *presence = [NSXMLElement elementWithName:@"presence"];
	[presence addAttributeWithName:@"type" stringValue:@"unavailable"];
	
	[[self xmppStream] sendElement:presence];
}

- (IBAction)changePresence:(id)sender
{
	if([[sender titleOfSelectedItem] isEqualToString:@"Offline"])
	{
		[self goOffline];
	}
	else
	{
		[self goOnline];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Buddy Management
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (IBAction)addBuddy:(id)sender
{
	XMPPJID *jid = [XMPPJID jidWithString:[buddyField stringValue]];
	
	[[self xmppRoster] addUser:jid withNickname:nil];
	
	// Clear buddy text field
	[buddyField setStringValue:@""];
}

- (IBAction)removeBuddy:(id)sender
{
	XMPPJID *jid = [XMPPJID jidWithString:[buddyField stringValue]];
	
	[[self xmppRoster] removeUser:jid];
	
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
		XMPPStream *stream = [self xmppStream];
		id <XMPPUser> user = [roster objectAtIndex:selectedRow];
		
		[ChatWindowManager openChatWindowWithStream:stream forUser:user];
	}
}

- (IBAction)connectViaXEP65:(id)sender
{
	int selectedRow = [rosterTable selectedRow];
	if(selectedRow >= 0)
	{
		id <XMPPUser> user = [roster objectAtIndex:selectedRow];
		id <XMPPResource> resource = [user primaryResource];
		
		[[NSApp delegate] connectViaXEP65:[resource jid]];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Roster Table Data Source
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [roster count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)rowIndex
{
	id <XMPPUser> user = [roster objectAtIndex:rowIndex];
	
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
	id <XMPPUser> user = [roster objectAtIndex:rowIndex];
	NSString *newName = (NSString *)anObject;
	
	[[self xmppRoster] setNickname:newName forUser:[user jid]];
}

- (void)tableView:(NSTableView *)tableView
  willDisplayCell:(id)cell
   forTableColumn:(NSTableColumn *)tableColumn 
			  row:(int)rowIndex
{
	id <XMPPUser> user = [roster objectAtIndex:rowIndex];
	
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
			grayColor = [NSColor colorWithCalibratedRed:(184.0F / 255.0F)
												  green:(175.0F / 255.0F)
												   blue:(184.0F / 255.0F)
												  alpha:1.0F];
		else
			grayColor = [NSColor colorWithCalibratedRed:(134.0F / 255.0F)
												  green:(125.0F / 255.0F)
												   blue:(134.0F / 255.0F)
												  alpha:1.0F];
			
		[cell setTextColor:grayColor];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPClient Delegate Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppStream:(XMPPStream *)sender willSecureWithSettings:(NSMutableDictionary *)settings
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
	
	if (allowSelfSignedCertificates)
	{
		[settings setObject:[NSNumber numberWithBool:YES] forKey:(NSString *)kCFStreamSSLAllowsAnyRoot];
	}
	
	if (allowSSLHostNameMismatch)
	{
		[settings setObject:[NSNull null] forKey:(NSString *)kCFStreamSSLPeerName];
	}
	else
	{
		// Google does things incorrectly (does not conform to RFC).
		// Because so many people ask questions about this (assume xmpp framework is broken),
		// I've explicitly added code that shows how other xmpp clients "do the right thing"
		// when connecting to a google server (gmail, or google apps for domains).
		
		NSString *expectedCertName = nil;
		
		NSString *serverHostName = [sender hostName];
		NSString *virtualHostName = [[sender myJID] domain];
		
		if ([serverHostName isEqualToString:@"talk.google.com"])
		{
			if ([virtualHostName isEqualToString:@"gmail.com"])
			{
				expectedCertName = virtualHostName;
			}
			else
			{
				expectedCertName = serverHostName;
			}
		}
		else
		{
			expectedCertName = serverHostName;
		}
		
		[settings setObject:expectedCertName forKey:(NSString *)kCFStreamSSLPeerName];
	}
}

- (void)xmppStreamDidSecure:(XMPPStream *)sender
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
}

- (void)xmppStreamDidConnect:(XMPPStream *)sender
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
	
	isOpen = YES;
	
	NSString *password = [passwordField stringValue];
	
	NSError *error = nil;
	BOOL success;
	
	if(isRegistering)
	{
		success = [[self xmppStream] registerWithPassword:password error:&error];
	}
	else
	{
		success = [[self xmppStream] authenticateWithPassword:password error:&error];
	}
	
	if (!success)
	{
		[messageField setStringValue:[error localizedDescription]];
	}
}

- (void)xmppStreamDidRegister:(XMPPStream *)sender
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
	
	// Update tracking variables
	isRegistering = NO;
	
	// Update GUI
	[self unlockSignInUI];
	[messageField setStringValue:@"Registered new user"];
}

- (void)xmppStream:(XMPPStream *)sender didNotRegister:(NSXMLElement *)error
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
	
	// Update tracking variables
	isRegistering = NO;
	
	// Update GUI
	[self unlockSignInUI];
	[messageField setStringValue:@"Username is taken"];
}

- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
	
	// Update tracking variables
	isAuthenticating = NO;
	
	// Close the sheet
	[signInSheet orderOut:self];
	[NSApp endSheet:signInSheet];
	
	// Send presence
	[self goOnline];
}

- (void)xmppStream:(XMPPStream *)sender didNotAuthenticate:(NSXMLElement *)error
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
	
	// Update tracking variables
	isAuthenticating = NO;
	
	// Update GUI
	[self unlockSignInUI];
	[messageField setStringValue:@"Invalid username/password"];
}

- (void)xmppRosterDidChange:(XMPPRosterMemoryStorage *)sender
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
	
	[roster release];
	roster = [[sender sortedUsersByAvailabilityName] retain];
	
	[rosterTable abortEditing];
	[rosterTable selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:NO];
	[rosterTable reloadData];
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
	
	if([message isChatMessageWithBody])
	{
		[ChatWindowManager handleChatMessage:message withStream:sender];
	}
}

- (void)xmppStream:(XMPPStream *)sender didReceiveError:(id)error
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
}

- (void)xmppStreamDidDisconnect:(XMPPStream *)sender withError:(NSError *)error
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
	
	if (!isOpen)
	{
		[messageField setStringValue:@"Cannot connect to server"];
	}
	
	// Update tracking variables
	isOpen = NO;
	isRegistering = NO;
	isAuthenticating = NO;
	
	// Update GUI
	[self unlockSignInUI];
}

@end
