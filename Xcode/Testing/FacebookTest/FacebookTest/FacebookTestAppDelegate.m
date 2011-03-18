#import "FacebookTestAppDelegate.h"
#import "FacebookTestViewController.h"
#import "XMPP.h"
#import "XMPPStreamFacebook.h"
#import "DDLog.h"
#import "DDTTYLogger.h"

// Log levels: off, error, warn, info, verbose
static const int ddLogLevel = LOG_LEVEL_VERBOSE;

// This is step #1 of X
// 
// But I just want to hit build and go and have everything work for me... <whine/> <pout/>
// 
// Too bad. You're a developer. Get over it.
// 
// Now go read this:
// http://developers.facebook.com/docs/guides/mobile/
// 
// And also this:
// http://code.google.com/p/xmppframework/wiki/FacebookChatHowTo
// 
//#define FACEBOOK_APP_ID @"PUT_YOUR_FACEBOOK_ID_HERE_FOR_EXAMPLE_123456789012345"


@implementation FacebookTestAppDelegate

@synthesize window = _window;
@synthesize viewController = _viewController;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	[DDLog addLogger:[DDTTYLogger sharedInstance]];
	
	self.window.rootViewController = self.viewController;
	[self.window makeKeyAndVisible];
	
	xmppStream = [[XMPPStreamFacebook alloc] init];
	
	xmppStream.myJID = [XMPPJID jidWithUser:@"user" domain:@"chat.facebook.com" resource:nil];
	
	[xmppStream addDelegate:self delegateQueue:dispatch_get_main_queue()];
	
	allowSelfSignedCertificates = NO;
	allowSSLHostNameMismatch = YES;
	
	facebook = [[Facebook alloc] initWithAppId:FACEBOOK_APP_ID]; // Go set FACEBOOK_APP_ID at top of file
	
	// Note: Be sure to invoke this AFTER the [self.window makeKeyAndVisible] method call above,
	//       or nothing will happen.
	
    [facebook authorize:[XMPPStreamFacebook permissions]
			   delegate:self
				appAuth:NO
			 safariAuth:NO];
	
    return YES;
}

- (void)dealloc
{
	[_window release];
	[_viewController release];
    [super dealloc];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Facebook Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
	
    return [facebook handleOpenURL:url]; 
}

- (void)fbDidLogin
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
	
	DDLogVerbose(@"%@: facebook.accessToken(%@)", THIS_FILE, facebook.accessToken);
	DDLogVerbose(@"%@: facebook.expirationDate(%@)", THIS_FILE, facebook.expirationDate);
	
	NSError *error = nil;
	if (![xmppStream connect:&error])
	{
		DDLogError(@"%@: Error in xmpp connection: %@", THIS_FILE, error);
	}
}

- (void)fbDidNotLogin:(BOOL)cancelled
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStream Delegate
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
		NSString *expectedCertName = [sender hostName];
		if (expectedCertName == nil)
		{
			expectedCertName = [[sender myJID] domain];
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
	
	NSError *error = nil;
	BOOL result = [xmppStream authenticateWithAppId:FACEBOOK_APP_ID       // Go set FACEBOOK_APP_ID at top of file
										accessToken:facebook.accessToken
									 expirationDate:facebook.expirationDate
											  error:&error];
	
	if (result == NO)
	{
		DDLogError(@"%@: Error in xmpp auth: %@", THIS_FILE, error);
	}
}

- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
}

- (void)xmppStream:(XMPPStream *)sender didNotAuthenticate:(NSXMLElement *)error
{
	DDLogVerbose(@"%@: %@ - error: %@", THIS_FILE, THIS_METHOD, error);
}

- (void)xmppStreamDidDisconnect:(XMPPStream *)sender withError:(NSError *)error
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
}

@end
