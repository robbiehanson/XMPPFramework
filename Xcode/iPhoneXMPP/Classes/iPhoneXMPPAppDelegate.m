#import "iPhoneXMPPAppDelegate.h"
#import "RootViewController.h"
#import "SettingsViewController.h"

#import "XMPP.h"
#import "XMPPRosterCoreDataStorage.h"
#import "XMPPvCardAvatarModule.h"
#import "XMPPvCardCoreDataStorageController.h"
#import "XMPPvCardTempModule.h"

#import <CFNetwork/CFNetwork.h>


@implementation iPhoneXMPPAppDelegate


@synthesize xmppStream;
@synthesize xmppRoster;
@synthesize xmppRosterStorage;
@synthesize xmppvCardAvatarModule = _xmppvCardAvatarModule;
@synthesize xmppvCardTempModule = _xmppvCardTempModule;

@synthesize window;
@synthesize navigationController;
@synthesize loginButton = _loginButton;
@synthesize settingsViewController = _settingsViewController;


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  //[window addSubview:[navigationController view]];
  self.window.rootViewController = self.navigationController;
	[self.window makeKeyAndVisible];

  [self setupStream];
  
  NSString *myJID = [[NSUserDefaults standardUserDefaults] stringForKey:kXMPPmyJID];
  NSString *myPassword = [[NSUserDefaults standardUserDefaults] stringForKey:kXMPPmyPassword];

  if (myJID == nil || myPassword == nil) {
    [self.navigationController presentModalViewController:self.settingsViewController animated:YES];
  }
	  
  return YES;
}

- (void)dealloc
{
	[xmppStream removeDelegate:self];
	[xmppRoster removeDelegate:self];
	
	[xmppStream disconnect];
  [_xmppvCardAvatarModule release];
  [_xmppvCardTempModule release];
	[xmppStream release];
	[xmppRoster release];
	
	[password release];
	
  [_loginButton release];
  [_settingsViewController release];
	[navigationController release];
	[window release];
	
	[super dealloc];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Custom
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


- (BOOL)connect {
  if ([xmppStream isConnected]) {
    return YES;
  }
  
  //
  // Uncomment the section below to hard code a JID and password.
  //
  // Replace me with the proper JID and password
  //	[xmppStream setMyJID:[XMPPJID jidWithString:@"user@gmail.com/iPhoneTest"]];
  //	password = @"password";
  
  // If you are NOT using SRV lookup based on the JID above,
  // replace me with the proper domain and port.
  // The example below is setup for a typical google talk account.
  //	[xmppStream setHostName:@"talk.google.com"];
  //	[xmppStream setHostPort:5222];
  //
  //  return YES;
  
  // or

  NSString *myJID = [[NSUserDefaults standardUserDefaults] stringForKey:kXMPPmyJID];
  NSString *myPassword = [[NSUserDefaults standardUserDefaults] stringForKey:kXMPPmyPassword];
  
  if (myJID != nil && myPassword != nil) {
    [xmppStream setMyJID:[XMPPJID jidWithString:myJID]];
    password = myPassword;
    
    // Uncomment me when the proper information has been entered above.
    NSError *error = nil;
    if ([xmppStream connect:&error])
    {
      return YES;
    }
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Error connecting" 
                                                        message:@"See console for error details." 
                                                       delegate:nil 
                                              cancelButtonTitle:@"Ok" 
                                              otherButtonTitles:nil];
    [alertView show];
    [alertView release];
    NSLog(@"Error connecting: %@", error);
  }
  return NO;
  
}

- (void)disconnect {
  [self goOffline];
  
  [xmppStream disconnect];
}

// It's easy to create XML elments to send and to read received XML elements.
// You have the entire NSXMLElement and NSXMLNode API's.
// 
// In addition to this, the NSXMLElementAdditions class provides some very handy methods for working with XMPP.
// 
// On the iPhone, Apple chose not to include the full NSXML suite.
// No problem - we use the KissXML library as a drop in replacement.
// 
// For more information on working with XML elements, see the Wiki article:
// http://code.google.com/p/xmppframework/wiki/WorkingWithElements

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

- (void)setupStream {
  xmppStream = [[XMPPStream alloc] init];
	xmppRosterStorage = [[XMPPRosterCoreDataStorage alloc] init];
	xmppRoster = [[XMPPRoster alloc] initWithStream:xmppStream rosterStorage:xmppRosterStorage];
	
	[xmppStream addDelegate:self];
	[xmppRoster addDelegate:self];
	
	[xmppRoster setAutoRoster:YES];
  
  _xmppvCardTempModule = [[XMPPvCardTempModule alloc] initWithStream:xmppStream 
                                                             storage:[XMPPvCardCoreDataStorageController sharedXMPPvCardCoreDataStorageController]];
  _xmppvCardAvatarModule = [[XMPPvCardAvatarModule alloc] initWithvCardTempModule:_xmppvCardTempModule];
  
  // You may need to alter these settings depending on the server you're connecting to
	allowSelfSignedCertificates = NO;
	allowSSLHostNameMismatch = NO;
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStream Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppStream:(XMPPStream *)sender willSecureWithSettings:(NSMutableDictionary *)settings
{
	NSLog(@"---------- xmppStream:willSecureWithSettings: ----------");
	
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
		
		NSString *serverDomain = xmppStream.hostName;
		NSString *virtualDomain = [xmppStream.myJID domain];
		
		if ([serverDomain isEqualToString:@"talk.google.com"])
		{
			if ([virtualDomain isEqualToString:@"gmail.com"])
			{
				expectedCertName = virtualDomain;
			}
			else
			{
				expectedCertName = serverDomain;
			}
		}
    else if (serverDomain == nil) {
      expectedCertName = virtualDomain;
    }
		else
		{
			expectedCertName = serverDomain;
		}
		
		[settings setObject:expectedCertName forKey:(NSString *)kCFStreamSSLPeerName];
	}
}

- (void)xmppStreamDidSecure:(XMPPStream *)sender
{
	NSLog(@"---------- xmppStreamDidSecure: ----------");
}

- (void)xmppStreamDidConnect:(XMPPStream *)sender
{
	NSLog(@"---------- xmppStreamDidConnect: ----------");
	
	isOpen = YES;
	
	NSError *error = nil;
	
	if (![[self xmppStream] authenticateWithPassword:password error:&error])
	{
		NSLog(@"Error authenticating: %@", error);
	}
}

- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender
{
	NSLog(@"---------- xmppStreamDidAuthenticate: ----------");
	
	[self goOnline];
}

- (void)xmppStream:(XMPPStream *)sender didNotAuthenticate:(NSXMLElement *)error
{
	NSLog(@"---------- xmppStream:didNotAuthenticate: ----------");
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
	NSLog(@"---------- xmppStream:didReceiveIQ: ----------");
	
	return NO;
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
	NSLog(@"---------- xmppStream:didReceiveMessage: ----------");
}

- (void)xmppStream:(XMPPStream *)sender didReceivePresence:(XMPPPresence *)presence
{
	NSLog(@"---------- xmppStream:didReceivePresence: ----------");
}

- (void)xmppStream:(XMPPStream *)sender didReceiveError:(id)error
{
	NSLog(@"---------- xmppStream:didReceiveError: ----------");
}

- (void)xmppStreamDidDisconnect:(XMPPStream *)sender
{
	NSLog(@"---------- xmppStreamDidDisconnect: ----------");
	
	if (!isOpen)
	{
		NSLog(@"Unable to connect to server. Check xmppStream.hostName");
	}
}

@end
