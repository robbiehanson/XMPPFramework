#import "FacebookTestAppDelegate.h"
#import "FacebookTestViewController.h"
#import "XMPP.h"
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
//
// http://code.google.com/p/xmppframework/wiki/FacebookChatHowTo
// 
// If the build fails, you may need to run the following command to setup 
// the facebook-ios-sdk:
//
// git submodule update --init

// For testing purposes this project uses the XMPPFacebook FBTest Facebook app.
#define FACEBOOK_APP_ID @"124242144347927"


@implementation FacebookTestAppDelegate

@synthesize window = _window;
@synthesize viewController = _viewController;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	[DDLog addLogger:[DDTTYLogger sharedInstance]];
	
	self.window.rootViewController = self.viewController;
	[self.window makeKeyAndVisible];
    
    self.viewController.statusLabel.text = @"Disconnected";
	
    // it is also possible to use init, but then we need to also set xmppStream.appId and xmppStream.hostName
	xmppStream = [[XMPPStream alloc] initWithFacebookAppId:FACEBOOK_APP_ID];
	
	[xmppStream addDelegate:self delegateQueue:dispatch_get_main_queue()];
	
	allowSelfSignedCertificates = NO;
	allowSSLHostNameMismatch = NO;
	
	facebook = [[Facebook alloc] initWithAppId:FACEBOOK_APP_ID andDelegate:self];
	
    self.viewController.statusLabel.text = @"Starting Facebook Authentication";
    
	// Note: Be sure to invoke this AFTER the [self.window makeKeyAndVisible] method call above,
	//       or nothing will happen.
    [facebook authorize:[NSArray arrayWithObject:@"xmpp_login"]];
	
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
	DDLogVerbose(@"%@: %@\nFacebook login successful!", THIS_FILE, THIS_METHOD);
	
	DDLogVerbose(@"%@: facebook.accessToken: %@", THIS_FILE, facebook.accessToken);
	DDLogVerbose(@"%@: facebook.expirationDate: %@", THIS_FILE, facebook.expirationDate);
	
    self.viewController.statusLabel.text = @"XMPP connecting...";
    
	NSError *error = nil;
	if (![xmppStream connect:&error])
	{
		DDLogError(@"%@: Error in xmpp connection: %@", THIS_FILE, error);
        self.viewController.statusLabel.text = @"XMPP connect failed";
	}
}

- (void)fbDidNotLogin:(BOOL)cancelled
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
    self.viewController.statusLabel.text = @"Facebook login failed";
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStream Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppStreamDidConnect:(XMPPStream *)sender
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
	
    if (![xmppStream isSecure])
    {
        self.viewController.statusLabel.text = @"XMPP STARTTLS...";
        NSError *error = nil;
        BOOL result = [xmppStream secureConnection:&error];
        
        if (result == NO)
        {
            DDLogError(@"%@: Error in xmpp STARTTLS: %@", THIS_FILE, error);
            self.viewController.statusLabel.text = @"XMPP STARTTLS failed";
        }
    } 
    else 
    {
        self.viewController.statusLabel.text = @"XMPP X-FACEBOOK-PLATFORM SASL...";
        NSError *error = nil;
        BOOL result = [xmppStream authenticateWithFacebookAccessToken:facebook.accessToken error:&error];
        
        if (result == NO)
        {
            DDLogError(@"%@: Error in xmpp auth: %@", THIS_FILE, error);
            self.viewController.statusLabel.text = @"XMPP authentication failed";
        }
    }
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
    self.viewController.statusLabel.text = @"XMPP STARTTLS...";
}

- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
    self.viewController.statusLabel.text = @"XMPP authenticated";
}

- (void)xmppStream:(XMPPStream *)sender didNotAuthenticate:(NSXMLElement *)error
{
	DDLogVerbose(@"%@: %@ - error: %@", THIS_FILE, THIS_METHOD, error);
    self.viewController.statusLabel.text = @"XMPP authentication failed";
}

- (void)xmppStreamDidDisconnect:(XMPPStream *)sender withError:(NSError *)error
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
    self.viewController.statusLabel.text = @"XMPP disconnected";
}

@end
