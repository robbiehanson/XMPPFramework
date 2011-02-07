#import "TestSRVResolverAppDelegate.h"
#import "RFSRVResolver.h"
#import "DDLog.h"
#import "DDTTYLogger.h"

// Log levels: off, error, warn, info, verbose
static const int ddLogLevel = LOG_LEVEL_VERBOSE;


@implementation TestSRVResolverAppDelegate

@synthesize window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	[DDLog addLogger:[DDTTYLogger sharedInstance]];
	
	srvResolver = [[RFSRVResolver alloc] initWithdDelegate:self
	                                         delegateQueue:dispatch_get_main_queue()
	                                         resolverQueue:NULL];
	
//	srvResolver = [[RFSRVResolver alloc] initWithdDelegate:self
//	                                         delegateQueue:dispatch_get_main_queue()
//	                                         resolverQueue:dispatch_get_main_queue()];
	
	NSString *domain = @"gmail.com";
//	NSString *domain = @"chat.facebook.com";
//	NSString *domain = @"deusty.com";
//	NSString *domain = @"someNonExistentDomain_moocow";
//	NSString *domain = nil;
	
	NSString *srvName = [RFSRVResolver srvNameFromXMPPDomain:domain];
	
	DDLogVerbose(@"XMPP Domain: %@", domain);
	DDLogVerbose(@"SRV Name: %@", srvName);
	
	[srvResolver startWithSRVName:srvName timeout:5.0];
	
//	[srvResolver stop];
}

- (void)srvResolver:(RFSRVResolver *)sender didResolveRecords:(NSArray *)records
{
	DDLogInfo(@"srvResolver:%p didResolveRecords:\n%@", sender, records);
}

- (void)srvResolver:(RFSRVResolver *)sender didNotResolveDueToError:(NSError *)error
{
	DDLogInfo(@"srvResolver:%p didNotResolveDueToError:\n%@", sender, error);
}

@end
