//
//  TestXEP82.m
//  TestXEP82
//
//  Created by Robbie Hanson on 4/12/11.
//  Copyright 2011 Deusty, LLC. All rights reserved.
//

#import "TestXEP82.h"
#import "XMPPDateTimeProfiles.h"

@implementation TestXEP82

static NSDateFormatter *df;

+ (void)initialize
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		
		df = [[NSDateFormatter alloc] init];
		[df setFormatterBehavior:NSDateFormatterBehavior10_4];
		[df setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS z"];
	});
}

+ (void)testParseDate
{
	// Should Succeed
	// 
	// Notice the proper time zones in the output.
	// The first date will be classified as standard GMT+HHMM as this is before DST was invented.
	// The second date takes place during daylight saving time.
	// The third date takes place during standard time.
	
	NSString *d1s = @"1776-07-04";
	NSString *d2s = @"1969-01-21";
	NSString *d3s = @"1969-07-21";
	NSString *d4s = @"2010-04-04";
	NSString *d5s = @"2010-12-25";
	
	NSLog(@"S parseDate(%@) = %@", d1s, [df stringFromDate:[XMPPDateTimeProfiles parseDate:d1s]]);
	NSLog(@"S parseDate(%@) = %@", d2s, [df stringFromDate:[XMPPDateTimeProfiles parseDate:d2s]]);
	NSLog(@"S parseDate(%@) = %@", d3s, [df stringFromDate:[XMPPDateTimeProfiles parseDate:d3s]]);
	NSLog(@"S parseDate(%@) = %@", d4s, [df stringFromDate:[XMPPDateTimeProfiles parseDate:d4s]]);
	NSLog(@"S parseDate(%@) = %@", d5s, [df stringFromDate:[XMPPDateTimeProfiles parseDate:d5s]]);
	
	NSLog(@" ");
	
	// Should Fail
	
	NSString *d1f = nil;
	NSString *d2f = @"1776-7-4";
	NSString *d3f = @"cheese";
	
	NSLog(@"F parseDate(%@) = %@", d1f, [df stringFromDate:[XMPPDateTimeProfiles parseDate:d1f]]);
	NSLog(@"F parseDate(%@) = %@", d2f, [df stringFromDate:[XMPPDateTimeProfiles parseDate:d2f]]);
	NSLog(@"F parseDate(%@) = %@", d3f, [df stringFromDate:[XMPPDateTimeProfiles parseDate:d3f]]);
}

+ (void)testParseTime
{
	// Should Succeed
	// 
	// Notice the proper time zones in the output.
	// All have been converted to the local time zone as needed.
	
	NSString *t1s = @"16:00:00";
	NSString *t2s = @"16:00:00Z";
	NSString *t3s = @"16:00:00-06:00";
	NSString *t4s = @"16:00:00.123";
	NSString *t5s = @"16:00:00.123Z";
	NSString *t6s = @"16:00:00.123-06:00";
	NSString *t7s = @"16:00:00.123456";
	NSString *t8s = @"16:00:00.123456Z";
	NSString *t9s = @"16:00:00.999511-06:00";
	
	NSLog(@"S parseTime(%@) = %@", t1s, [df stringFromDate:[XMPPDateTimeProfiles parseTime:t1s]]);
	NSLog(@"S parseTime(%@) = %@", t2s, [df stringFromDate:[XMPPDateTimeProfiles parseTime:t2s]]);
	NSLog(@"S parseTime(%@) = %@", t3s, [df stringFromDate:[XMPPDateTimeProfiles parseTime:t3s]]);
	NSLog(@"S parseTime(%@) = %@", t4s, [df stringFromDate:[XMPPDateTimeProfiles parseTime:t4s]]);
	NSLog(@"S parseTime(%@) = %@", t5s, [df stringFromDate:[XMPPDateTimeProfiles parseTime:t5s]]);
	NSLog(@"S parseTime(%@) = %@", t6s, [df stringFromDate:[XMPPDateTimeProfiles parseTime:t6s]]);
	NSLog(@"S parseTime(%@) = %@", t7s, [df stringFromDate:[XMPPDateTimeProfiles parseTime:t7s]]);
	NSLog(@"S parseTime(%@) = %@", t8s, [df stringFromDate:[XMPPDateTimeProfiles parseTime:t8s]]);
	NSLog(@"S parseTime(%@) = %@", t9s, [df stringFromDate:[XMPPDateTimeProfiles parseTime:t9s]]);

	NSLog(@" ");
	
	// Should Fail
	
	NSString *t1f = nil;
	NSString *t2f = @"16-00-00";
	NSString *t3f = @"16:00:00-0600";
	NSString *t4f = @"16:00:00.";
	NSString *t5f = @"16:00.123";
	NSString *t6f = @"cheese";
	
	NSLog(@"F parseTime(%@) = %@", t1f, [df stringFromDate:[XMPPDateTimeProfiles parseTime:t1f]]);
	NSLog(@"F parseTime(%@) = %@", t2f, [df stringFromDate:[XMPPDateTimeProfiles parseTime:t2f]]);
	NSLog(@"F parseTime(%@) = %@", t3f, [df stringFromDate:[XMPPDateTimeProfiles parseTime:t3f]]);
	NSLog(@"F parseTime(%@) = %@", t4f, [df stringFromDate:[XMPPDateTimeProfiles parseTime:t4f]]);
	NSLog(@"F parseTime(%@) = %@", t5f, [df stringFromDate:[XMPPDateTimeProfiles parseTime:t5f]]);
	NSLog(@"F parseTime(%@) = %@", t6f, [df stringFromDate:[XMPPDateTimeProfiles parseTime:t6f]]);
}

+ (void)testParseDateTime
{
	// Should Succeed
	// 
	// Notice the proper time zones in the output.
	
	NSString *dt01s = @"1776-07-04T02:56:15Z";
	NSString *dt02s = @"1776-07-04T21:56:15-05:00";
	NSString *dt03s = @"1776-07-04T02:56:15.123Z";
	NSString *dt04s = @"1776-07-04T21:56:15.123-05:00";
  NSString *dt05s = @"1776-07-04T02:56:15.123456Z";
  NSString *dt06s = @"1776-07-04T21:56:15.999511-05:00";

	NSLog(@"S parseDateTime(%@) = %@", dt01s, [df stringFromDate:[XMPPDateTimeProfiles parseDateTime:dt01s]]);
	NSLog(@"S parseDateTime(%@) = %@", dt02s, [df stringFromDate:[XMPPDateTimeProfiles parseDateTime:dt02s]]);
	NSLog(@"S parseDateTime(%@) = %@", dt03s, [df stringFromDate:[XMPPDateTimeProfiles parseDateTime:dt03s]]);
	NSLog(@"S parseDateTime(%@) = %@", dt04s, [df stringFromDate:[XMPPDateTimeProfiles parseDateTime:dt04s]]);
	NSLog(@"S parseDateTime(%@) = %@", dt05s, [df stringFromDate:[XMPPDateTimeProfiles parseDateTime:dt05s]]);
	NSLog(@"S parseDateTime(%@) = %@", dt06s, [df stringFromDate:[XMPPDateTimeProfiles parseDateTime:dt06s]]);

	NSLog(@" ");
	
	NSString *dt07s = @"1969-01-21T02:56:15Z";
	NSString *dt08s = @"1969-01-20T21:56:15-05:00";
	NSString *dt09s = @"1969-01-21T02:56:15.123Z";
	NSString *dt10s = @"1969-01-21T21:56:15.123-05:00";
	NSString *dt11s = @"1969-01-21T02:56:15.123456Z";
	NSString *dt12s = @"1969-01-21T21:56:15.999511-05:00";

	NSLog(@"S parseDateTime(%@) = %@", dt07s, [df stringFromDate:[XMPPDateTimeProfiles parseDateTime:dt07s]]);
	NSLog(@"S parseDateTime(%@) = %@", dt08s, [df stringFromDate:[XMPPDateTimeProfiles parseDateTime:dt08s]]);
	NSLog(@"S parseDateTime(%@) = %@", dt09s, [df stringFromDate:[XMPPDateTimeProfiles parseDateTime:dt09s]]);
	NSLog(@"S parseDateTime(%@) = %@", dt10s, [df stringFromDate:[XMPPDateTimeProfiles parseDateTime:dt10s]]);
	NSLog(@"S parseDateTime(%@) = %@", dt11s, [df stringFromDate:[XMPPDateTimeProfiles parseDateTime:dt11s]]);
	NSLog(@"S parseDateTime(%@) = %@", dt12s, [df stringFromDate:[XMPPDateTimeProfiles parseDateTime:dt12s]]);

	NSLog(@" ");
	
	NSString *dt13s = @"1969-07-21T02:56:15Z";
	NSString *dt14s = @"1969-07-20T21:56:15-05:00";
	NSString *dt15s = @"1969-07-21T02:56:15.123Z";
	NSString *dt16s = @"1969-07-21T21:56:15.123-05:00";
	NSString *dt17s = @"1969-07-21T02:56:15.123456Z";
	NSString *dt18s = @"1969-07-21T21:56:15.999511-05:00";

	NSLog(@"S parseDateTime(%@) = %@", dt13s, [df stringFromDate:[XMPPDateTimeProfiles parseDateTime:dt13s]]);
	NSLog(@"S parseDateTime(%@) = %@", dt14s, [df stringFromDate:[XMPPDateTimeProfiles parseDateTime:dt14s]]);
	NSLog(@"S parseDateTime(%@) = %@", dt15s, [df stringFromDate:[XMPPDateTimeProfiles parseDateTime:dt15s]]);
	NSLog(@"S parseDateTime(%@) = %@", dt16s, [df stringFromDate:[XMPPDateTimeProfiles parseDateTime:dt16s]]);
	NSLog(@"S parseDateTime(%@) = %@", dt17s, [df stringFromDate:[XMPPDateTimeProfiles parseDateTime:dt17s]]);
	NSLog(@"S parseDateTime(%@) = %@", dt18s, [df stringFromDate:[XMPPDateTimeProfiles parseDateTime:dt18s]]);

	NSLog(@" ");

	NSString *dt19s = @"2010-04-04T02:56:15Z";
	NSString *dt20s = @"2010-04-04T21:56:15-05:00";
	NSString *dt21s = @"2010-04-04T02:56:15.123Z";
	NSString *dt22s = @"2010-04-04T21:56:15.123-05:00";
	NSString *dt23s = @"2010-04-04T02:56:15.123456Z";
	NSString *dt24s = @"2010-04-04T21:56:15.999511-05:00";

	NSLog(@"S parseDateTime(%@) = %@", dt19s, [df stringFromDate:[XMPPDateTimeProfiles parseDateTime:dt19s]]);
	NSLog(@"S parseDateTime(%@) = %@", dt20s, [df stringFromDate:[XMPPDateTimeProfiles parseDateTime:dt20s]]);
	NSLog(@"S parseDateTime(%@) = %@", dt21s, [df stringFromDate:[XMPPDateTimeProfiles parseDateTime:dt21s]]);
	NSLog(@"S parseDateTime(%@) = %@", dt22s, [df stringFromDate:[XMPPDateTimeProfiles parseDateTime:dt22s]]);
	NSLog(@"S parseDateTime(%@) = %@", dt23s, [df stringFromDate:[XMPPDateTimeProfiles parseDateTime:dt23s]]);
	NSLog(@"S parseDateTime(%@) = %@", dt24s, [df stringFromDate:[XMPPDateTimeProfiles parseDateTime:dt24s]]);

	NSLog(@" ");
	
	NSString *dt25s = @"2010-12-25T02:56:15Z";
	NSString *dt26s = @"2010-12-25T21:56:15-05:00";
	NSString *dt27s = @"2010-12-25T02:56:15.123Z";
	NSString *dt28s = @"2010-12-25T21:56:15.123-05:00";
	NSString *dt29s = @"2010-12-25T02:56:15.123456Z";
	NSString *dt30s = @"2010-12-25T21:56:15.999511-05:00";

	NSLog(@"S parseDateTime(%@) = %@", dt25s, [df stringFromDate:[XMPPDateTimeProfiles parseDateTime:dt25s]]);
	NSLog(@"S parseDateTime(%@) = %@", dt26s, [df stringFromDate:[XMPPDateTimeProfiles parseDateTime:dt26s]]);
	NSLog(@"S parseDateTime(%@) = %@", dt27s, [df stringFromDate:[XMPPDateTimeProfiles parseDateTime:dt27s]]);
	NSLog(@"S parseDateTime(%@) = %@", dt28s, [df stringFromDate:[XMPPDateTimeProfiles parseDateTime:dt28s]]);
	NSLog(@"S parseDateTime(%@) = %@", dt29s, [df stringFromDate:[XMPPDateTimeProfiles parseDateTime:dt29s]]);
	NSLog(@"S parseDateTime(%@) = %@", dt30s, [df stringFromDate:[XMPPDateTimeProfiles parseDateTime:dt30s]]);

	NSLog(@" ");
	
	// Should Fail
	
	NSString *dt1f = nil;
	NSString *dt2f = @"1969-07-20 21:56:15Z";
	NSString *dt3f = @"1969-7-4T02:56:15.123Z";
	NSString *dt4f = @"1969-7-4T02:56:15.Z";
	NSString *dt5f = @"cheese";
	
	NSLog(@"F parseDateTime(%@) = %@", dt1f, [df stringFromDate:[XMPPDateTimeProfiles parseDateTime:dt1f]]);
	NSLog(@"F parseDateTime(%@) = %@", dt2f, [df stringFromDate:[XMPPDateTimeProfiles parseDateTime:dt2f]]);
	NSLog(@"F parseDateTime(%@) = %@", dt3f, [df stringFromDate:[XMPPDateTimeProfiles parseDateTime:dt3f]]);
	NSLog(@"F parseDateTime(%@) = %@", dt4f, [df stringFromDate:[XMPPDateTimeProfiles parseDateTime:dt4f]]);
	NSLog(@"F parseDateTime(%@) = %@", dt5f, [df stringFromDate:[XMPPDateTimeProfiles parseDateTime:dt5f]]);
}

+ (void)testCategory
{
	NSDate *now = [NSDate date];
	
	NSLog(@"now(%@).xmppDateString = %@", now, [now xmppDateString]);
	NSLog(@"now(%@).xmppTimeString = %@", now, [now xmppTimeString]);
	NSLog(@"now(%@).xmppDateTimeString = %@", now, [now xmppDateTimeString]);
}

+ (void)runTests
{
	NSLog(@"now = %@", [df stringFromDate:[NSDate date]]);
	NSLog(@"---------------------------------------------------------------------------------------------------------");
	
	[self testParseDate];
	NSLog(@"---------------------------------------------------------------------------------------------------------");
	
	[self testParseTime];
	NSLog(@"---------------------------------------------------------------------------------------------------------");
	
	[self testParseDateTime];
	NSLog(@"---------------------------------------------------------------------------------------------------------");
	
	[self testCategory];
	NSLog(@"---------------------------------------------------------------------------------------------------------");
}

@end
