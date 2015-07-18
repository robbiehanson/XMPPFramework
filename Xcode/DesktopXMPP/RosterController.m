#import "RosterController.h"
#import "RequestController.h"
#import "WindowManager.h"
#import "AppDelegate.h"
#import "DDLog.h"
#import "SSKeychain.h"

#import <SystemConfiguration/SystemConfiguration.h>

// Log levels: off, error, warn, info, verbose
static const int ddLogLevel = LOG_LEVEL_VERBOSE;


@implementation RosterController

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Setup:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (XMPPStream *)xmppStream
{
	return [(AppDelegate *)[NSApp delegate] xmppStream];
}

- (XMPPRoster *)xmppRoster
{
	return [(AppDelegate *)[NSApp delegate] xmppRoster];
}

- (XMPPRosterMemoryStorage *)xmppRosterStorage
{
	return [(AppDelegate *)[NSApp delegate] xmppRosterStorage];
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
	
	[serverField              setObjectValue:[dflts objectForKey:@"Account.Server"]];
	[portField                setObjectValue:[dflts objectForKey:@"Account.Port"]];
	[sslButton                setObjectValue:[dflts objectForKey:@"Account.UseSSL"]];
	[customCertEvalButton     setObjectValue:[dflts objectForKey:@"Account.CustomCertEvaluation"]];
	[jidField                 setObjectValue:[dflts objectForKey:@"Account.JID"]];
	[rememberPasswordCheckbox setObjectValue:[dflts objectForKey:@"Account.RememberPassword"]];
	[resourceField            setObjectValue:[dflts objectForKey:@"Account.Resource"]];
	
	if ([rememberPasswordCheckbox state] == NSOnState)
	{
		NSString *jidStr = [[jidField stringValue] lowercaseString];
		
		NSString *password = [SSKeychain passwordForService:@"XMPPFramework" account:jidStr];
		if (password)
		{
			[passwordField setStringValue:password];
		}
		
		// If user was prompted for keychain permission, we may need to restore focus to our application
		[NSApp activateIgnoringOtherApps:YES];
	}
							  
	[NSApp beginSheet:signInSheet
	   modalForWindow:window
	    modalDelegate:self
	   didEndSelector:nil
	      contextInfo:nil];
	
	// Set keyboard focus
							  
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
	
	// Update domain placeholder
	
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
		
		if ([rememberPasswordCheckbox state] == NSOnState)
		{
			// Autofill password if there's a saved password for this JID
			
			NSString *jidStr = [[jidField stringValue] lowercaseString];
			
			NSString *password = [SSKeychain passwordForService:@"XMPPFramework" account:jidStr];
			if (password)
			{
				[passwordField setStringValue:password];
			}
		}
	}
}

- (void)enableSignInUI:(BOOL)enabled
{
	[serverField setEnabled:enabled];
	[portField setEnabled:enabled];
	
	[sslButton setEnabled:enabled];
	[customCertEvalButton setEnabled:enabled];
	
	[jidField setEnabled:enabled];
	[passwordField setEnabled:enabled];
	[rememberPasswordCheckbox setEnabled:enabled];
	
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
	self.xmppStream.hostName = domain;
	
	int port = [portField intValue];
	self.xmppStream.hostPort = port;
	
	useSSL               = ([sslButton state] == NSOnState);
	customCertEvaluation = ([customCertEvalButton state] == NSOnState);
	
	NSString *resource = [resourceField stringValue];
	if ([resource length] == 0)
	{
		resource = (__bridge_transfer NSString *)SCDynamicStoreCopyComputerName(NULL, NULL);
	}
	
	XMPPJID *jid = [XMPPJID jidWithString:[jidField stringValue] resource:resource];
	self.xmppStream.myJID = jid;
	
	// Update persistent info
	
	NSUserDefaults *dflts = [NSUserDefaults standardUserDefaults];
	
	[dflts setObject:domain forKey:@"Account.Server"];
	
	[dflts setObject:(port ? [NSNumber numberWithInt:port] : nil)
			  forKey:@"Account.Port"];
	
	[dflts setObject:[jidField stringValue]
			  forKey:@"Account.JID"];
	
	[dflts setObject:[resourceField stringValue]
			  forKey:@"Account.Resource"];
	
	[dflts setBool:useSSL               forKey:@"Account.UseSSL"];
	[dflts setBool:customCertEvaluation forKey:@"Account.CustomCertEvaluation"];
	
	if ([rememberPasswordCheckbox state] == NSOnState)
	{
		NSString *jidStr   = [jidField stringValue];
		NSString *password = [passwordField stringValue];
		
		[SSKeychain setPassword:password forService:@"XMPPFramework" account:jidStr];
		
		[dflts setBool:YES forKey:@"Account.RememberPassword"];
	}
	else
	{
		[dflts setBool:NO forKey:@"Account.RememberPassword"];
	}
	
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
			success = [[self xmppStream] oldSchoolSecureConnectWithTimeout:XMPPStreamTimeoutNone error:&error];
		else
			success = [[self xmppStream] connectWithTimeout:XMPPStreamTimeoutNone error:&error];
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
	[signInSheet makeFirstResponder:nil]; // workaround for some odd UI bug I don't understand
	
	[self updateAccountInfo];
	
	NSError *error = nil;
	BOOL success;
	
	if(![[self xmppStream] isConnected])
	{
		if (useSSL)
			success = [[self xmppStream] oldSchoolSecureConnectWithTimeout:XMPPStreamTimeoutNone error:&error];
		else
			success = [[self xmppStream] connectWithTimeout:XMPPStreamTimeoutNone error:&error];
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
#pragma mark MUC Sheet
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (IBAction)mucCancel:(id)sender
{
	// Close the sheet
	[mucSheet orderOut:self];
	[NSApp endSheet:mucSheet];
}

- (IBAction)mucJoin:(id)sender
{
	// Close the sheet
	[mucSheet orderOut:self];
	[NSApp endSheet:mucSheet];
	
	// Open MUC window
	XMPPJID *jid = [XMPPJID jidWithString:[mucRoomField stringValue]];
	if (jid)
	{
		[WindowManager openMucWindowWithStream:[self xmppStream] forRoom:jid];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Presence Management
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)goOnline
{
	XMPPPresence *presence = [XMPPPresence presence]; // type="available" is implicit
    
    NSString *domain = [[[self xmppStream] myJID] domain];
    
    //Google set their presence priority to 24, so we do the same to be compatible.
    
    if([domain isEqualToString:@"gmail.com"]
       || [domain isEqualToString:@"gtalk.com"]
       || [domain isEqualToString:@"talk.google.com"])
    {
        NSXMLElement *priority = [NSXMLElement elementWithName:@"priority" stringValue:@"24"];
        [presence addChild:priority];
    }
	
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
#pragma mark IBActions
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (IBAction)muc:(id)sender
{
	[NSApp beginSheet:mucSheet
	   modalForWindow:window
	    modalDelegate:self
	   didEndSelector:nil
	      contextInfo:nil];
}

- (IBAction)connectViaXEP65:(id)sender
{
	int selectedRow = [rosterTable selectedRow];
	if(selectedRow >= 0)
	{
		id <XMPPUser> user = [roster objectAtIndex:selectedRow];
		id <XMPPResource> resource = [user primaryResource];
		
		[(AppDelegate *)[NSApp delegate] connectViaXEP65:[resource jid]];
	}
}

- (IBAction)chat:(id)sender
{
	int selectedRow = [rosterTable selectedRow];
	if (selectedRow >= 0)
	{
		XMPPStream *stream = [self xmppStream];
		id <XMPPUser> user = [roster objectAtIndex:selectedRow];
		
		[WindowManager openChatWindowWithStream:stream forUser:user];
	}
}

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
#pragma mark Roster Table Data Source
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [roster count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	id <XMPPUser> user = [roster objectAtIndex:rowIndex];
	
	if ([[tableColumn identifier] isEqualToString:@"name"])
		return [user nickname];
	else
		return [user jid];
	
	return nil;
}

- (void)tableView:(NSTableView *)tableView
  willDisplayCell:(id)cell
   forTableColumn:(NSTableColumn *)tableColumn 
			  row:(NSInteger)rowIndex
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

- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	DDLogVerbose(@"tableView:shouldEditTableColumn:\"%@\" row:%li", [aTableColumn identifier], (long)rowIndex);
	
	if ([[aTableColumn identifier] isEqualToString:@"name"])
	{
		return YES;
	}
	else
	{
		XMPPStream *stream = [self xmppStream];
		id <XMPPUser> user = [roster objectAtIndex:rowIndex];
		
		DDLogVerbose(@"user: %@", user);
		if (user)
		{
			[WindowManager openChatWindowWithStream:stream forUser:user];
		}
		
		return NO;
	}
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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPClient Delegate Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppStream:(XMPPStream *)sender willSecureWithSettings:(NSMutableDictionary *)settings
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
	
	NSString *expectedCertName = [sender.myJID domain];
	if (expectedCertName)
	{
		[settings setObject:expectedCertName forKey:(NSString *)kCFStreamSSLPeerName];
	}
	
	if (customCertEvaluation)
	{
		[settings setObject:@(YES) forKey:GCDAsyncSocketManuallyEvaluateTrust];
	}
}

/**
 * Allows a delegate to hook into the TLS handshake and manually validate the peer it's connecting to.
 *
 * This is only called if the stream is secured with settings that include:
 * - GCDAsyncSocketManuallyEvaluateTrust == YES
 * That is, if a delegate implements xmppStream:willSecureWithSettings:, and plugs in that key/value pair.
 *
 * Thus this delegate method is forwarding the TLS evaluation callback from the underlying GCDAsyncSocket.
 *
 * Typically the delegate will use SecTrustEvaluate (and related functions) to properly validate the peer.
 *
 * Note from Apple's documentation:
 *   Because [SecTrustEvaluate] might look on the network for certificates in the certificate chain,
 *   [it] might block while attempting network access. You should never call it from your main thread;
 *   call it only from within a function running on a dispatch queue or on a separate thread.
 *
 * This is why this method uses a completionHandler block rather than a normal return value.
 * The idea is that you should be performing SecTrustEvaluate on a background thread.
 * The completionHandler block is thread-safe, and may be invoked from a background queue/thread.
 * It is safe to invoke the completionHandler block even if the socket has been closed.
 * 
 * Keep in mind that you can do all kinds of cool stuff here.
 * For example:
 * 
 * If your development server is using a self-signed certificate,
 * then you could embed info about the self-signed cert within your app, and use this callback to ensure that
 * you're actually connecting to the expected dev server.
 * 
 * Also, you could present certificates that don't pass SecTrustEvaluate to the client.
 * That is, if SecTrustEvaluate comes back with problems, you could invoke the completionHandler with NO,
 * and then ask the client if the cert can be trusted. This is similar to how most browsers act.
 * 
 * Generally, only one delegate should implement this method.
 * However, if multiple delegates implement this method, then the first to invoke the completionHandler "wins".
 * And subsequent invocations of the completionHandler are ignored.
**/
- (void)xmppStream:(XMPPStream *)sender didReceiveTrust:(SecTrustRef)trust
                                      completionHandler:(void (^)(BOOL shouldTrustPeer))completionHandler
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
	
	// The delegate method should likely have code similar to this,
	// but will presumably perform some extra security code stuff.
	// For example, allowing a specific self-signed certificate that is known to the app.
	
	dispatch_queue_t bgQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
	dispatch_async(bgQueue, ^{
		
		SecTrustResultType result = kSecTrustResultDeny;
		OSStatus status = SecTrustEvaluate(trust, &result);
		
		if (status == noErr && (result == kSecTrustResultProceed || result == kSecTrustResultUnspecified)) {
			completionHandler(YES);
		}
		else {
			completionHandler(NO);
		}
	});
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
	BOOL operationInProgress;
	
	if (isRegistering)
	{
		// Start **_asynchronous_** operation.
		// 
		// If there's some kind of problem, the method will return NO and report the reason.
		// For example: "server doesn't support in-band-registration"
		// 
		operationInProgress = [[self xmppStream] registerWithPassword:password error:&error];
	}
	else
	{
		// Start **_asynchronous_** operation.
		// 
		// If there's some kind of problem, the method will return NO and report the reason.
		// For example: "xmpp stream isn't connected"
		// 
		operationInProgress = [[self xmppStream] authenticateWithPassword:password error:&error];
	}
	
	if (!operationInProgress)
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
	
	roster = [sender sortedUsersByAvailabilityName];
	
	[rosterTable abortEditing];
	[rosterTable selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:NO];
	[rosterTable reloadData];
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
	
	if ([message isChatMessageWithBody])
	{
		[WindowManager handleMessage:message withStream:sender];
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
