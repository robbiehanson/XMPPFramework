#import "TestXEP82AppDelegate.h"
#import "XMPPDateTimeProfiles.h"

@implementation TestXEP82AppDelegate

@synthesize window;

- (void)testDate
{
	// Should Succeed
	
	NSString *d1s = @"1776-07-04";
	
	NSLog(@"parseDate(%@) = %@", d1s, [XMPPDateTimeProfiles parseDate:d1s]);
	
	// Should Fail
	
	NSString *d1f = nil;
	NSString *d2f = @"1776-7-4";
	NSString *d3f = @"cheese";
	
	NSLog(@"parseDate(%@) = %@", d1f, [XMPPDateTimeProfiles parseDate:d1f]);
	NSLog(@"parseDate(%@) = %@", d2f, [XMPPDateTimeProfiles parseDate:d2f]);
	NSLog(@"parseDate(%@) = %@", d3f, [XMPPDateTimeProfiles parseDate:d3f]);
}

- (void)testTime
{
	// Should Succeed
	
	NSString *t1s = @"16:00:00";
	NSString *t2s = @"16:00:00Z";
	NSString *t3s = @"16:00:00-06:00";
	NSString *t4s = @"16:00:00.123";
	NSString *t5s = @"16:00:00.123Z";
	NSString *t6s = @"16:00:00.123-06:00";
	
	NSLog(@"parseTime(%@) = %@", t1s, [XMPPDateTimeProfiles parseTime:t1s]);
	NSLog(@"parseTime(%@) = %@", t2s, [XMPPDateTimeProfiles parseTime:t2s]);
	NSLog(@"parseTime(%@) = %@", t3s, [XMPPDateTimeProfiles parseTime:t3s]);
	NSLog(@"parseTime(%@) = %@", t4s, [XMPPDateTimeProfiles parseTime:t4s]);
	NSLog(@"parseTime(%@) = %@", t5s, [XMPPDateTimeProfiles parseTime:t5s]);
	NSLog(@"parseTime(%@) = %@", t6s, [XMPPDateTimeProfiles parseTime:t6s]);
	
	// Should Fail
	
	NSString *t1f = nil;
	NSString *t2f = @"16-00-00";
	NSString *t3f = @"16:00:00-0600";
	NSString *t4f = @"16:00:00.1";
	NSString *t5f = @"16:00.123";
	NSString *t6f = @"cheese";
	
	NSLog(@"parseTime(%@) = %@", t1f, [XMPPDateTimeProfiles parseTime:t1f]);
	NSLog(@"parseTime(%@) = %@", t2f, [XMPPDateTimeProfiles parseTime:t2f]);
	NSLog(@"parseTime(%@) = %@", t3f, [XMPPDateTimeProfiles parseTime:t3f]);
	NSLog(@"parseTime(%@) = %@", t4f, [XMPPDateTimeProfiles parseTime:t4f]);
	NSLog(@"parseTime(%@) = %@", t5f, [XMPPDateTimeProfiles parseTime:t5f]);
	NSLog(@"parseTime(%@) = %@", t6f, [XMPPDateTimeProfiles parseTime:t6f]);
}

- (void)testDateTime
{
	// Should Succeed
	
	NSString *dt1s = @"1969-07-21T02:56:15Z";
	NSString *dt2s = @"1969-07-20T21:56:15-05:00";
	NSString *dt3s = @"1969-07-21T02:56:15.123Z";
	NSString *dt4s = @"1969-07-21T21:56:15.123-05:00";
	
	NSLog(@"parseDateTime(%@) = %@", dt1s, [XMPPDateTimeProfiles parseDateTime:dt1s]);
	NSLog(@"parseDateTime(%@) = %@", dt2s, [XMPPDateTimeProfiles parseDateTime:dt2s]);
	NSLog(@"parseDateTime(%@) = %@", dt3s, [XMPPDateTimeProfiles parseDateTime:dt3s]);
	NSLog(@"parseDateTime(%@) = %@", dt4s, [XMPPDateTimeProfiles parseDateTime:dt4s]);
	
	// Should Fail
	
	NSString *dt1f = nil;
	NSString *dt2f = @"1969-07-20 21:56:15Z";
	NSString *dt3f = @"1969-7-4T02:56:15.123Z";
	NSString *dt4f = @"cheese";
	
	NSLog(@"parseDateTime(%@) = %@", dt1f, [XMPPDateTimeProfiles parseDateTime:dt1f]);
	NSLog(@"parseDateTime(%@) = %@", dt2f, [XMPPDateTimeProfiles parseDateTime:dt2f]);
	NSLog(@"parseDateTime(%@) = %@", dt3f, [XMPPDateTimeProfiles parseDateTime:dt3f]);
	NSLog(@"parseDateTime(%@) = %@", dt4f, [XMPPDateTimeProfiles parseDateTime:dt4f]);
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	NSLog(@"now = %@", [NSDate date]);
	NSLog(@"----------------------------------------------------------------------------");
	
	[self testDate];
	NSLog(@"----------------------------------------------------------------------------");
	
	[self testTime];
	NSLog(@"----------------------------------------------------------------------------");
	
	[self testDateTime];
	NSLog(@"----------------------------------------------------------------------------");
}

@end
