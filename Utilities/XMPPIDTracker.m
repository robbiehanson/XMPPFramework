#import "XMPPIDTracker.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

/**
 * Does ARC support support GCD objects?
 * It does if the minimum deployment target is iOS 6+ or Mac OS X 10.8+
**/
#if TARGET_OS_IPHONE

  // Compiling for iOS

  #if __IPHONE_OS_VERSION_MIN_REQUIRED >= 60000 // iOS 6.0 or later
    #define NEEDS_DISPATCH_RETAIN_RELEASE 0
  #else                                         // iOS 5.X or earlier
    #define NEEDS_DISPATCH_RETAIN_RELEASE 1
  #endif

#else

  // Compiling for Mac OS X

  #if MAC_OS_X_VERSION_MIN_REQUIRED >= 1080     // Mac OS X 10.8 or later
    #define NEEDS_DISPATCH_RETAIN_RELEASE 0
  #else
    #define NEEDS_DISPATCH_RETAIN_RELEASE 1     // Mac OS X 10.7 or earlier
  #endif

#endif

#define AssertProperQueue() NSAssert(dispatch_get_current_queue() == queue, @"Invoked on incorrect queue")

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPIDTracker

- (id)init
{
	// You must use initWithDispatchQueue
	
	return nil;
}

- (id)initWithDispatchQueue:(dispatch_queue_t)aQueue
{
	NSParameterAssert(aQueue != NULL);
	
	if ((self = [super init]))
	{
		queue = aQueue;
		#if NEEDS_DISPATCH_RETAIN_RELEASE
		dispatch_retain(queue);
		#endif
		
		dict = [[NSMutableDictionary alloc] init];
	}
	return self;
}

- (void)dealloc
{
	// We don't call [self removeAllIDs] because dealloc might not be invoked on queue
	
	for (id <XMPPTrackingInfo> info in [dict objectEnumerator])
	{
		[info cancelTimer];
	}
	[dict removeAllObjects];
	
	#if NEEDS_DISPATCH_RETAIN_RELEASE
	dispatch_release(queue);
	#endif
}

- (void)addID:(NSString *)elementID target:(id)target selector:(SEL)selector timeout:(NSTimeInterval)timeout
{
	AssertProperQueue();
	
	XMPPBasicTrackingInfo *trackingInfo;
	trackingInfo = [[XMPPBasicTrackingInfo alloc] initWithTarget:target selector:selector timeout:timeout];
	
	[self addID:elementID trackingInfo:trackingInfo];
}

- (void)addID:(NSString *)elementID
        block:(void (^)(id obj, id <XMPPTrackingInfo> info))block
      timeout:(NSTimeInterval)timeout
{
	AssertProperQueue();
	
	XMPPBasicTrackingInfo *trackingInfo;
	trackingInfo = [[XMPPBasicTrackingInfo alloc] initWithBlock:block timeout:timeout];
	
	[self addID:elementID trackingInfo:trackingInfo];
}

- (void)addID:(NSString *)elementID trackingInfo:(id <XMPPTrackingInfo>)trackingInfo
{
	AssertProperQueue();
	
	[dict setObject:trackingInfo forKey:elementID];
	
	[trackingInfo setElementID:elementID];
	[trackingInfo createTimerWithDispatchQueue:queue];
}

- (BOOL)invokeForID:(NSString *)elementID withObject:(id)obj
{
	AssertProperQueue();
	
	id <XMPPTrackingInfo> info = [dict objectForKey:elementID];
	if (info)
	{
		[info invokeWithObject:obj];
		[info cancelTimer];
		[dict removeObjectForKey:elementID];
		
		return YES;
	}
	
	return NO;
}

- (void)removeID:(NSString *)elementID
{
	AssertProperQueue();
	
	id <XMPPTrackingInfo> info = [dict objectForKey:elementID];
	if (info)
	{
		[info cancelTimer];
		[dict removeObjectForKey:elementID];
	}
}

- (void)removeAllIDs
{
	AssertProperQueue();
	
	for (id <XMPPTrackingInfo> info in [dict objectEnumerator])
	{
		[info cancelTimer];
	}
	[dict removeAllObjects];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPBasicTrackingInfo

@synthesize timeout;
@synthesize elementID;

- (id)init
{
	// Use initWithTarget:selector:timeout: or initWithBlock:timeout:
	
	return nil;
}

- (id)initWithTarget:(id)aTarget selector:(SEL)aSelector timeout:(NSTimeInterval)aTimeout
{
	NSParameterAssert(aTarget);
	NSParameterAssert(aSelector);
	
	if ((self = [super init]))
	{
		target = aTarget;
		selector = aSelector;
		timeout = aTimeout;
	}
	return self;
}

- (id)initWithBlock:(void (^)(id obj, id <XMPPTrackingInfo> info))aBlock timeout:(NSTimeInterval)aTimeout
{
	NSParameterAssert(aBlock);
	
	if ((self = [super init]))
	{
		block = [aBlock copy];
		timeout = aTimeout;
	}
	return self;
}

- (void)dealloc
{
	[self cancelTimer];
	
	target = nil;
	selector = NULL;
}

- (void)createTimerWithDispatchQueue:(dispatch_queue_t)queue
{
	NSAssert(queue != NULL, @"Method invoked with NULL queue");
	NSAssert(timer == NULL, @"Method invoked multiple times");
	
	if (timeout > 0.0)
	{
		timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
		
		dispatch_source_set_event_handler(timer, ^{ @autoreleasepool {
			
			[self invokeWithObject:nil];
			
		}});
		
		dispatch_time_t tt = dispatch_time(DISPATCH_TIME_NOW, (timeout * NSEC_PER_SEC));
		
		dispatch_source_set_timer(timer, tt, DISPATCH_TIME_FOREVER, 0);
		dispatch_resume(timer);
	}
}

- (void)cancelTimer
{
	if (timer)
	{
		dispatch_source_cancel(timer);
		#if NEEDS_DISPATCH_RETAIN_RELEASE
		dispatch_release(timer);
		#endif
		timer = NULL;
	}
}

- (void)invokeWithObject:(id)obj
{
	if (block)
		block(obj, self);
	else
	{
		#pragma clang diagnostic push
		#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
		[target performSelector:selector withObject:obj withObject:self];
		#pragma clang diagnostic pop
	}
}

@end
