#import "TestSRVResolverAppDelegate.h"
#import "XMPPSRVResolver.h"
#import "DDLog.h"
#import "DDTTYLogger.h"

// Log levels: off, error, warn, info, verbose
static const int ddLogLevel = LOG_LEVEL_VERBOSE;


@implementation TestSRVResolverAppDelegate

@synthesize window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	[DDLog addLogger:[DDTTYLogger sharedInstance]];
	
	srvResolver = [[XMPPSRVResolver alloc] initWithdDelegate:self
                                               delegateQueue:dispatch_get_main_queue()
                                               resolverQueue:NULL];
	
//	srvResolver = [[XMPPSRVResolver alloc] initWithdDelegate:self
//	                                         delegateQueue:dispatch_get_main_queue()
//	                                         resolverQueue:dispatch_get_main_queue()];
	
	NSString *domain = @"gmail.com";
//	NSString *domain = @"chat.facebook.com";
//	NSString *domain = @"deusty.com";
//	NSString *domain = @"someNonExistentDomain_moocow";
//	NSString *domain = nil;
	
	NSString *srvName = [XMPPSRVResolver srvNameFromXMPPDomain:domain];
	
	DDLogVerbose(@"XMPP Domain: %@", domain);
	DDLogVerbose(@"SRV Name: %@", srvName);
	
	[srvResolver startWithSRVName:srvName timeout:5.0];
	
//	[srvResolver stop];
}

- (void)xmppSRVResolver:(XMPPSRVResolver *)sender didResolveRecords:(NSArray *)records
{
	DDLogInfo(@"srvResolver:%p didResolveRecords:\n%@", sender, records);
}

- (void)xmppSRVResolver:(XMPPSRVResolver *)sender didNotResolveDueToError:(NSError *)error
{
	DDLogInfo(@"srvResolver:%p didNotResolveDueToError:\n%@", sender, error);
}

@end
