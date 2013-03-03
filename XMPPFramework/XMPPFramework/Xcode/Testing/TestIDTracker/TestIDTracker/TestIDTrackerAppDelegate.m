#import "TestIDTrackerAppDelegate.h"
#import "XMPPIDTracker.h"
#import "DDLog.h"
#import "DDTTYLogger.h"

// Log levels: off, error, warn, info, verbose
static const int ddLogLevel = LOG_LEVEL_VERBOSE;

@interface ExtendedTrackingInfo : XMPPBasicTrackingInfo
{
	NSDate *timeSent;
}

@property (nonatomic, readonly) NSDate *timeSent;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation TestIDTrackerAppDelegate

@synthesize window;

- (NSString *)generateUUID
{
	NSString *result = nil;
	
	CFUUIDRef uuid = CFUUIDCreate(NULL);
	if (uuid)
	{
		result = (__bridge_transfer NSString *)CFUUIDCreateString(NULL, uuid);
		CFRelease(uuid);
	}
	
	return result;
}

- (void)scheduleFakeFetchResponseWithID:(NSString *)elementID obj:(id)obj timeout:(NSTimeInterval)timeout
{
	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:elementID, @"elementID",
						  obj, @"obj", nil];
	
	[NSTimer scheduledTimerWithTimeInterval:timeout
	                                 target:self
	                               selector:@selector(fakeFetchResponse:)
	                               userInfo:dict
	                                repeats:NO];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	[DDLog addLogger:[DDTTYLogger sharedInstance]];
	
	idTracker = [[XMPPIDTracker alloc] initWithDispatchQueue:dispatch_get_main_queue()];
	
	fetch1 = [self generateUUID];
	fetch2 = [self generateUUID];
	fetch3 = [self generateUUID];
	fetch4 = [self generateUUID];
	
	[idTracker addID:fetch1 target:self selector:@selector(simpleProcessFetch:withInfo:) timeout:2.0];
	[idTracker addID:fetch2 target:self selector:@selector(simpleProcessFetch:withInfo:) timeout:4.0];
	
	[self scheduleFakeFetchResponseWithID:fetch2 obj:@"quack" timeout:3.0];
	
	void (^simpleBlock)(id, id <XMPPTrackingInfo>) = ^(id obj, id <XMPPTrackingInfo> info) {
		DDLogVerbose(@"simpleBlock(%@, %@)", obj, info);
		if (obj == nil)
			DDLogVerbose(@"timeout = %f", info.timeout);
	};
	
	[idTracker addID:fetch3 block:simpleBlock timeout:6.0];
	[idTracker addID:fetch4 block:simpleBlock timeout:8.0];
	
	[self scheduleFakeFetchResponseWithID:fetch4 obj:@"moo" timeout:7.0];
	
	fetch5 = [self generateUUID];
	fetch6 = [self generateUUID];
	fetch7 = [self generateUUID];
	fetch8 = [self generateUUID];
	
	SEL selector = @selector(advancedProcessFetch:withInfo:);
	
	ExtendedTrackingInfo *info5 = [[ExtendedTrackingInfo alloc] initWithTarget:self selector:selector timeout:10.0];
	ExtendedTrackingInfo *info6 = [[ExtendedTrackingInfo alloc] initWithTarget:self selector:selector timeout:12.0];
	
	[idTracker addID:fetch5 trackingInfo:info5];
	[idTracker addID:fetch6 trackingInfo:info6];
	
	[self scheduleFakeFetchResponseWithID:fetch6 obj:@"quack" timeout:11.0];
	
	void (^advancedBlock)(NSString *, ExtendedTrackingInfo *) = ^(NSString *obj, ExtendedTrackingInfo *info) {
		DDLogVerbose(@"advancedBlock(%@, %@)", obj, info);
		if (obj == nil)
			DDLogVerbose(@"timeout = %f", info.timeout);
		else
			DDLogVerbose(@"timeSent = %@", info.timeSent);
	};
	
	ExtendedTrackingInfo *info7 = [[ExtendedTrackingInfo alloc] initWithBlock:advancedBlock timeout:14.0];
	ExtendedTrackingInfo *info8 = [[ExtendedTrackingInfo alloc] initWithBlock:advancedBlock timeout:16.0];
	
	[idTracker addID:fetch7 trackingInfo:info7];
	[idTracker addID:fetch8 trackingInfo:info8];
	
	[self scheduleFakeFetchResponseWithID:fetch8 obj:@"moo" timeout:15.0];
}

- (void)simpleProcessFetch:(id)obj withInfo:(id <XMPPTrackingInfo>)info
{
	DDLogVerbose(@"simpleProcessFetch:%@ withInfo:%@", obj, info);
	if (obj == nil)
		DDLogVerbose(@"timeout = %f", info.timeout);
}

- (void)advancedProcessFetch:(id)obj withInfo:(ExtendedTrackingInfo *)info
{
	DDLogVerbose(@"advancedProcessFetch:%@ withInfo:%@", obj, info);
	if (obj == nil)
		DDLogVerbose(@"timeout = %f", info.timeout);
	else
		DDLogVerbose(@"timeSent = %@", info.timeSent);
}

- (void)fakeFetchResponse:(NSTimer *)aTimer
{
	DDLogVerbose(@"fakeFetchResponse:");
	
	NSDictionary *dict = [aTimer userInfo];
	
	NSString *elementID = [dict objectForKey:@"elementID"];
	id obj = [dict objectForKey:@"obj"];
	
	if ([idTracker invokeForID:elementID withObject:obj])
		DDLogVerbose(@"got it");
	else
		DDLogVerbose(@"huh?");
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation ExtendedTrackingInfo

@synthesize timeSent;

- (id)initWithTarget:(id)aTarget selector:(SEL)aSelector timeout:(NSTimeInterval)aTimeout
{
	if ((self = [super initWithTarget:aTarget selector:aSelector timeout:aTimeout]))
	{
		timeSent = [[NSDate alloc] init];
	}
	return self;
}

- (id)initWithBlock:(void (^)(id obj, id <XMPPTrackingInfo> info))aBlock timeout:(NSTimeInterval)aTimeout
{
	if ((self = [super initWithBlock:aBlock timeout:aTimeout]))
	{
		timeSent = [[NSDate alloc] init];
	}
	return self;
}

@end
