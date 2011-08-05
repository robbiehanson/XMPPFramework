#import "TestElementReceiptAppDelegate.h"
#import "XMPPStream.h"

@interface XMPPElementReceipt (PrivateAPI) // Stolen from XMPPStream.m

- (void)signalSuccess;
- (void)signalFailure;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation TestElementReceiptAppDelegate

@synthesize window;

- (void)test1
{
	NSLog(@"========== test1 ==========");
	
	XMPPElementReceipt *receipt = [[[XMPPElementReceipt alloc] init] autorelease];
	
	BOOL result = [receipt wait:0.0];
	NSLog(@"NO =?= %@", (result ? @"YES" : @"NO"));
}

- (void)test2
{
	NSLog(@"========== test2 ==========");
	
	XMPPElementReceipt *receipt = [[[XMPPElementReceipt alloc] init] autorelease];
	
	dispatch_queue_t concurrentQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
	
	double delayInSeconds = 2.0;
	dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
	dispatch_after(popTime, concurrentQueue, ^{
		[receipt signalSuccess];
	});
	
	BOOL result = [receipt wait:4.0];
	NSLog(@"YES =?= %@", (result ? @"YES" : @"NO"));
}

- (void)test3
{
	NSLog(@"========== test3 ==========");
	
	XMPPElementReceipt *receipt = [[[XMPPElementReceipt alloc] init] autorelease];
	
	dispatch_queue_t concurrentQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
	
	double delayInSeconds = 5.0;
	dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
	dispatch_after(popTime, concurrentQueue, ^{
		[receipt signalSuccess];
	});
	
	BOOL result1 = [receipt wait:3.0];
	NSLog(@"NO =?= %@", (result1 ? @"YES" : @"NO"));
	
	BOOL result2 = [receipt wait:3.0];
	NSLog(@"YES =?= %@", (result2 ? @"YES" : @"NO"));
}

- (void)test4
{
	NSLog(@"========== test4 ==========");
	
	XMPPElementReceipt *receipt = [[[XMPPElementReceipt alloc] init] autorelease];
	
	dispatch_queue_t concurrentQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
	
	double delayInSeconds = 2.0;
	dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
	dispatch_after(popTime, concurrentQueue, ^{
		[receipt signalFailure];
	});
	
	BOOL result1 = [receipt wait:4.0];
	NSLog(@"NO =?= %@", (result1 ? @"YES" : @"NO"));
	
	BOOL result2 = [receipt wait:4.0];
	NSLog(@"NO =?= %@", (result2 ? @"YES" : @"NO"));
}

- (void)test5
{
	NSLog(@"========== test5 ==========");
	
	XMPPElementReceipt *receipt = [[[XMPPElementReceipt alloc] init] autorelease];
	
	dispatch_queue_t concurrentQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
	
	double delayInSeconds = 1.0;
	dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
	dispatch_after(popTime, concurrentQueue, ^{
		[receipt signalSuccess];
	});
	
	BOOL result;
	do
	{
		result = [receipt wait:0.1];
		NSLog(@"result == %@", (result ? @"YES" : @"NO"));
		
	} while (!result);
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	dispatch_queue_t myQueue = dispatch_queue_create("Testing", NULL);
	dispatch_async(myQueue, ^{
		[self test1];
		[self test2];
		[self test3];
		[self test4];
		[self test5];
	});
}

@end
