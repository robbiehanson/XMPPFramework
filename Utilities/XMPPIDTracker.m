#import "XMPPIDTracker.h"

#define AssertProperQueue() NSAssert(dispatch_get_current_queue() == queue, @"Invoked on incorrect queue")

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPIDTracker

- (id)init
{
	// You must use initWithDispatchQueue
	
	[self release];
	return nil;
}

- (id)initWithDispatchQueue:(dispatch_queue_t)aQueue
{
	NSParameterAssert(aQueue != NULL);
	
	if ((self = [super init]))
	{
		queue = aQueue;
		dispatch_retain(queue);
		
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
	[dict release];
	
	dispatch_release(queue);
	
	[super dealloc];
}

- (void)addID:(NSString *)elementID target:(id)target selector:(SEL)selector timeout:(NSTimeInterval)timeout
{
	AssertProperQueue();
	
	XMPPBasicTrackingInfo *trackingInfo;
	trackingInfo = [[XMPPBasicTrackingInfo alloc] initWithTarget:target selector:selector timeout:timeout];
	
	[self addID:elementID trackingInfo:trackingInfo];
	[trackingInfo release];
}

- (void)addID:(NSString *)elementID
        block:(void (^)(id obj, id <XMPPTrackingInfo> info))block
      timeout:(NSTimeInterval)timeout
{
	AssertProperQueue();
	
	XMPPBasicTrackingInfo *trackingInfo;
	trackingInfo = [[XMPPBasicTrackingInfo alloc] initWithBlock:block timeout:timeout];
	
	[self addID:elementID trackingInfo:trackingInfo];
	[trackingInfo release];
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
	
	[self release];
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
		block = Block_copy(aBlock);
		timeout = aTimeout;
	}
	return self;
}

- (void)dealloc
{
	[self cancelTimer];
	
	target = nil;
	selector = NULL;
	
	if (block) {
		Block_release(block);
		block = NULL;
	}
	
	[elementID release];
	
	[super dealloc];
}

- (void)createTimerWithDispatchQueue:(dispatch_queue_t)queue
{
	NSAssert(queue != NULL, @"Method invoked with NULL queue");
	NSAssert(timer == NULL, @"Method invoked multiple times");
	
	if (timeout > 0.0)
	{
		timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
		
		dispatch_source_set_event_handler(timer, ^{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			
			[self invokeWithObject:nil];
			
			[pool drain];
		});
		
		dispatch_time_t tt = dispatch_time(DISPATCH_TIME_NOW, (timeout * NSEC_PER_SEC));
		
		dispatch_source_set_timer(timer, tt, DISPATCH_TIME_FOREVER, 0);
		dispatch_resume(timer);
	}
}

- (void)cancelTimer
{
	if (timer) {
		dispatch_source_cancel(timer);
		dispatch_release(timer);
		timer = NULL;
	}
}

- (void)invokeWithObject:(id)obj
{
	if (block)
		block(obj, self);
	else
		[target performSelector:selector withObject:obj withObject:self];
}

@end
