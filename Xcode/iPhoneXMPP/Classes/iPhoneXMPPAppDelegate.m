#import "iPhoneXMPPAppDelegate.h"
#import "RootViewController.h"
#import "SettingsViewController.h"

#import "GCDAsyncSocket.h"
#import "XMPP.h"
#import "XMPPReconnect.h"
#import "XMPPCapabilitiesCoreDataStorage.h"
#import "XMPPRosterCoreDataStorage.h"
#import "XMPPvCardAvatarModule.h"
#import "XMPPvCardCoreDataStorage.h"

#import "DDLog.h"
#import "DDTTYLogger.h"

#import <CFNetwork/CFNetwork.h>

// Log levels: off, error, warn, info, verbose
static const int ddLogLevel = LOG_LEVEL_VERBOSE;


@interface iPhoneXMPPAppDelegate()

- (void)setupStream;

- (void)goOnline;
- (void)goOffline;

@end

#pragma mark -
@implementation iPhoneXMPPAppDelegate

@synthesize xmppStream;
@synthesize xmppReconnect;
@synthesize xmppCapabilities;
@synthesize xmppRoster;
@synthesize xmppvCardAvatarModule;
@synthesize xmppvCardTempModule;

@synthesize window;
@synthesize navigationController;
@synthesize settingsViewController;
@synthesize loginButton;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	// Configure logging framework
	
	[DDLog addLogger:[DDTTYLogger sharedInstance]];
    
	// Setup the view controllers

	[window setRootViewController:navigationController];
	[window makeKeyAndVisible];

	// Setup the XMPP stream

	[self setupStream];

	if (![self connect]) {
		[navigationController presentModalViewController:settingsViewController animated:YES];
	}
		
	return YES;
}

- (void)dealloc
{
	[xmppStream removeDelegate:self];
	[xmppRoster removeDelegate:self];

	[xmppStream disconnect];
	[xmppReconnect release];
	[xmppvCardAvatarModule release];
	[xmppvCardTempModule release];
    [xmppCapabilities release];
	[xmppStream release];
	[xmppRoster release];

	[password release];

	[loginButton release];
	[settingsViewController release];
	[navigationController release];
	[window release];

	[super dealloc];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Private
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Configure the xmpp stream
- (void)setupStream
{
	// Setup xmpp stream
	// 
	// The XMPPStream is the base class for all activity.
	// Everything else plugs into the xmppStream, such as modules/extensions and delegates.

	xmppStream = [[XMPPStream alloc] init];
	
	#if !TARGET_IPHONE_SIMULATOR
	{
		// Want xmpp to run in the background?
		// 
		// P.S. - The simulator doesn't support backgrounding yet.
		//        When you try to set the associated property on the simulator, it simply fails.
		//        And when you background an app on the simulator,
		//        it just queues network traffic til the app is foregrounded again.
		//        We are patiently waiting for a fix from Apple.
		//        If you do enableBackgroundingOnSocket on the simulator,
		//        you will simply see an error message from the xmpp stack when it fails to set the property.
		
		xmppStream.enableBackgroundingOnSocket = YES;
	}
	#endif
	
	// Setup roster
	// 
	// The XMPPRoster handles the xmpp protocol stuff related to the roster.
	// The storage for the roster is abstracted.
	// So you can use any storage mechanism you want.
	// You can store it all in memory, or use core data and store it on disk, or use core data with an in-memory store,
	// or setup your own using raw SQLite, or create your own storage mechanism.
	// You can do it however you like! It's your application.
	// But you do need to provide the roster with some storage facility.
	
	id <XMPPRosterStorage> rosterStorage = [[[XMPPRosterCoreDataStorage alloc] init] autorelease];
//	id <XMPPRosterStorage> rosterStorage = [[[XMPPRosterCoreDataStorage alloc] initWithInMemoryStore] autorelease];
	
	xmppRoster = [[XMPPRoster alloc] initWithRosterStorage:rosterStorage];
	
	// Setup vCard support
	
	// We add XMPPRoster as a delegate of XMPPvCardAvatarModule to cache roster photos in the roster.
	// This frees the view controller from having to save photos on the main thread.
	
	id <XMPPvCardTempModuleStorage> vcardStorage = [XMPPvCardCoreDataStorage sharedInstance];
	xmppvCardTempModule = [[XMPPvCardTempModule alloc] initWithvCardStorage:vcardStorage];
	
	xmppvCardAvatarModule = [[XMPPvCardAvatarModule alloc] initWithvCardTempModule:xmppvCardTempModule];
	
	[xmppvCardAvatarModule addDelegate:xmppRoster delegateQueue:xmppRoster.moduleQueue];
	
	// Setup reconnect
	// 
	// The XMPPReconnect module monitors for "accidental disconnections" and
	// automatically reconnects the stream for you.
	// There's a bunch more information in the XMPPReconnect header file.
	
	xmppReconnect = [[XMPPReconnect alloc] init];
	
	// Setup capabilities
	// 
	// The XMPPCapabilities module handles all the complex hashing of the caps protocol (XEP-0115).
	// Basically, when other clients broadcast their presence on the network
	// they include information about what capabilities their client supports (audio, video, file transfer, etc).
	// But as you can imagine, this list starts to get pretty big.
	// This is where the hashing stuff comes into play.
	// Most people running the same version of the same client are going to have the same list of capabilities.
	// So the protocol defines a standardized way to hash the list of capabilities.
	// Clients then broadcast the tiny hash instead of the big list.
	// The XMPPCapabilities protocol automatically handles figuring out what these hashes mean,
	// and also persistently storing the hashes so lookups aren't needed in the future.
	// 
	// Similarly to the roster, the storage of the module is abstracted.
	// You are strongly encouraged to persist caps information across sessions.
	// 
	// The XMPPCapabilitiesCoreDataStorage is an ideal solution.
	// It can also be shared amongst multiple streams to further reduce hash lookups.
	
	id <XMPPCapabilitiesStorage> capsStorage = [XMPPCapabilitiesCoreDataStorage sharedInstance];
    xmppCapabilities = [[XMPPCapabilities alloc] initWithCapabilitiesStorage:capsStorage];

    xmppCapabilities.autoFetchHashedCapabilities = YES;
    xmppCapabilities.autoFetchNonHashedCapabilities = NO;

	[xmppRoster setAutoRoster:YES];

	// Activate xmpp modules

	[xmppReconnect activate:xmppStream];
    [xmppCapabilities activate:xmppStream];
	[xmppRoster activate:xmppStream];
	[xmppvCardTempModule activate:xmppStream];
	[xmppvCardAvatarModule activate:xmppStream];

	// Add ourself as a delegate to anything we may be interested in

	[xmppStream addDelegate:self delegateQueue:dispatch_get_main_queue()];
	[xmppRoster addDelegate:self delegateQueue:dispatch_get_main_queue()];

	// Optional:
	// 
	// Replace me with the proper domain and port.
	// The example below is setup for a typical google talk account.
	// 
	// If you don't supply a hostName, then it will be automatically resolved using the JID (below).
	// For example, if you supply a JID like 'user@quack.com/rsrc'
	// then the xmpp framework will follow the xmpp specification, and do a SRV lookup for quack.com.
	// 
	// If you don't specify a hostPort, then the default (5222) will be used.
	
//	[xmppStream setHostName:@"talk.google.com"];
//	[xmppStream setHostPort:5222];	
	

	// You may need to alter these settings depending on the server you're connecting to
	allowSelfSignedCertificates = NO;
	allowSSLHostNameMismatch = NO;
}

// It's easy to create XML elments to send and to read received XML elements.
// You have the entire NSXMLElement and NSXMLNode API's.
// 
// In addition to this, the NSXMLElement+XMPP category provides some very handy methods for working with XMPP.
// 
// On the iPhone, Apple chose not to include the full NSXML suite.
// No problem - we use the KissXML library as a drop in replacement.
// 
// For more information on working with XML elements, see the Wiki article:
// http://code.google.com/p/xmppframework/wiki/WorkingWithElements

- (void)goOnline
{
	XMPPPresence *presence = [XMPPPresence presence]; // type="available" is implicit
	
	[[self xmppStream] sendElement:presence];
}

- (void)goOffline
{
	XMPPPresence *presence = [XMPPPresence presenceWithType:@"unavailable"];
	
	[[self xmppStream] sendElement:presence];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Connect/disconnect
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)connect
{
	if (![xmppStream isDisconnected]) {
		return YES;
	}

	NSString *myJID = [[NSUserDefaults standardUserDefaults] stringForKey:kXMPPmyJID];
	NSString *myPassword = [[NSUserDefaults standardUserDefaults] stringForKey:kXMPPmyPassword];

	//
	// If you don't want to use the Settings view to set the JID, 
	// uncomment the section below to hard code a JID and password.
	//
	// Replace me with the proper JID and password:
	//	myJID = @"user@gmail.com/xmppframework";
	//	myPassword = @"";

	if (myJID == nil || myPassword == nil) {
		DDLogWarn(@"JID and password must be set before connecting!");

		return NO;
	}

	[xmppStream setMyJID:[XMPPJID jidWithString:myJID]];
	password = myPassword;

	NSError *error = nil;
	if (![xmppStream connect:&error])
	{
		UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Error connecting" 
		                                                    message:@"See console for error details." 
		                                                   delegate:nil 
		                                          cancelButtonTitle:@"Ok" 
		                                          otherButtonTitles:nil];
		[alertView show];
		[alertView release];

		DDLogError(@"Error connecting: %@", error);

		return NO;
	}

	return YES;
}

- (void)disconnect {
  [self goOffline];
  
  [xmppStream disconnect];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark UIApplicationDelegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)applicationDidEnterBackground:(UIApplication *)application 
{
  /*
   Use this method to release shared resources, save user data, invalidate timers, and store enough application state 
   information to restore your application to its current state in case it is terminated later. 
   If your application supports background execution, called instead of applicationWillTerminate: when the user quits.
   */
  DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
  
#if TARGET_IPHONE_SIMULATOR
  DDLogError(@"The iPhone simulator does not process background network traffic.  Inbound traffic is queued until the keepAliveTimeout:handler: fires.");
#endif
  
  if ([application respondsToSelector:@selector(setKeepAliveTimeout:handler:)]) 
  {
    [application setKeepAliveTimeout:600 handler:^{
      DDLogVerbose(@"KeepAliveHandler");
      
      // Do other keep alive stuff here.
    }];
  }
}

- (void)applicationWillEnterForeground:(UIApplication *)application 
{
  DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPRosterDelegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppRoster:(XMPPRoster *)sender didReceiveBuddyRequest:(XMPPPresence *)presence
{
  DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
  
  NSString *displayName = [[xmppRoster userForJID:[presence from]] displayName];
  NSString *jidStrBare = [presence fromStr];
  NSString *body = nil;
  
  if (![displayName isEqualToString:jidStrBare]) 
  {
    body = [NSString stringWithFormat:@"Buddy request from %@ <%@>", displayName, jidStrBare];
  } 
  else 
  {
    body = [NSString stringWithFormat:@"Buddy request from %@", displayName];
  }
  
  
  if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive)
  {
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:displayName
                                                        message:body 
                                                       delegate:nil 
                                              cancelButtonTitle:@"Not implemented" 
                                              otherButtonTitles:nil];
    [alertView show];
    [alertView release];
  } 
  else 
  {
    // We are not active, so use a local notification instead
    UILocalNotification *localNotification = [[UILocalNotification alloc] init];
    localNotification.alertAction = @"Not implemented";
    localNotification.alertBody = body;
    
    [[UIApplication sharedApplication] presentLocalNotificationNow:localNotification];
    [localNotification release];
  }

}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStream Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppStream:(XMPPStream *)sender socketDidConnect:(GCDAsyncSocket *)socket 
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
}

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
		else if (serverDomain == nil)
		{
			expectedCertName = virtualDomain;
		}
		else
		{
			expectedCertName = serverDomain;
		}
		
		if (expectedCertName)
		{
			[settings setObject:expectedCertName forKey:(NSString *)kCFStreamSSLPeerName];
		}
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
	
	NSError *error = nil;
	
	if (![[self xmppStream] authenticateWithPassword:password error:&error])
	{
		DDLogError(@"Error authenticating: %@", error);
	}
}

- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
	
	[self goOnline];
}

- (void)xmppStream:(XMPPStream *)sender didNotAuthenticate:(NSXMLElement *)error
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
	DDLogVerbose(@"%@: %@ - %@", THIS_FILE, THIS_METHOD, [iq elementID]);
	
	return NO;
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
  
  // A simple example of inbound message handling.
  
  if ([message isChatMessageWithBody])
  {
    NSString *body = [[message elementForName:@"body"] stringValue];    
    NSString *displayName = [[xmppRoster userForJID:[message from]] displayName];

    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive)
    {
      UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:displayName
                                                          message:body 
                                                         delegate:nil 
                                                cancelButtonTitle:@"Ok" 
                                                otherButtonTitles:nil];
      [alertView show];
      [alertView release];
    } else {
      // We are not active, so use a local notification instead
      UILocalNotification *localNotification = [[UILocalNotification alloc] init];
      localNotification.alertAction = @"Ok";
      localNotification.alertBody = [NSString stringWithFormat:@"From: %@\n\n%@",displayName,body];
      
      [[UIApplication sharedApplication] presentLocalNotificationNow:localNotification];
      [localNotification release];
    }
  }
}

- (void)xmppStream:(XMPPStream *)sender didReceivePresence:(XMPPPresence *)presence
{
	DDLogVerbose(@"%@: %@ - %@", THIS_FILE, THIS_METHOD, [presence fromStr]);
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
		DDLogError(@"Unable to connect to server. Check xmppStream.hostName");
	}
}

@end
