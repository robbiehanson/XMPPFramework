#import "XMPPIDTracker.h"
#import "XMPP.h"
#import "XMPPLogging.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

// Log levels: off, error, warn, info, verbose
// Log flags: trace
#if DEBUG
static const int xmppLogLevel = XMPP_LOG_LEVEL_VERBOSE; // | XMPP_LOG_FLAG_TRACE;
#else
static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

#define AssertProperQueue() NSAssert(dispatch_get_specific(queueTag), @"Invoked on incorrect queue")

const NSTimeInterval XMPPIDTrackerTimeoutNone = -1;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface XMPPIDTracker ()
{
	void *queueTag;
}

@end

@implementation XMPPIDTracker

- (id)init
{
	// You must use initWithDispatchQueue or initWithStream:dispatchQueue:
	return nil;
}

- (id)initWithDispatchQueue:(dispatch_queue_t)aQueue
{
	return [self initWithStream:nil dispatchQueue:aQueue];
}

- (id)initWithStream:(XMPPStream *)stream dispatchQueue:(dispatch_queue_t)aQueue
{
    NSParameterAssert(aQueue != NULL);
	
	if ((self = [super init]))
	{
        xmppStream = stream;
        
		queue = aQueue;
		
		queueTag = &queueTag;
		dispatch_queue_set_specific(queue, queueTag, queueTag, NULL);
		
#if !OS_OBJECT_USE_OBJC
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
	
	#if !OS_OBJECT_USE_OBJC
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

- (void)addElement:(XMPPElement *)element target:(id)target selector:(SEL)selector timeout:(NSTimeInterval)timeout
{
	AssertProperQueue();
	
	XMPPBasicTrackingInfo *trackingInfo;
	trackingInfo = [[XMPPBasicTrackingInfo alloc] initWithTarget:target selector:selector timeout:timeout];
	
	[self addElement:element trackingInfo:trackingInfo];
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


- (void)addElement:(XMPPElement *)element 
             block:(void (^)(id obj, id <XMPPTrackingInfo> info))block
           timeout:(NSTimeInterval)timeout
{
	AssertProperQueue();
	
	XMPPBasicTrackingInfo *trackingInfo;
	trackingInfo = [[XMPPBasicTrackingInfo alloc] initWithBlock:block timeout:timeout];
	
	[self addElement:element trackingInfo:trackingInfo];
}

- (void)addID:(NSString *)elementID trackingInfo:(id <XMPPTrackingInfo>)trackingInfo
{
	AssertProperQueue();
	
	[dict setObject:trackingInfo forKey:elementID];
	
	[trackingInfo setElementID:elementID];
	[trackingInfo createTimerWithDispatchQueue:queue];
}

- (void)addElement:(XMPPElement *)element trackingInfo:(id <XMPPTrackingInfo>)trackingInfo
{
	AssertProperQueue();
    
    if([[element elementID] length] == 0) return;
	
	[dict setObject:trackingInfo forKey:[element elementID]];
	
	[trackingInfo setElementID:[element elementID]];
    [trackingInfo setElement:element];
	[trackingInfo createTimerWithDispatchQueue:queue];
}

- (BOOL)invokeForID:(NSString *)elementID withObject:(id)obj
{
	AssertProperQueue();
    
    if([elementID length] == 0) return NO;
	
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

- (BOOL)invokeForElement:(XMPPElement *)element withObject:(id)obj
{
    AssertProperQueue();
    
    if([[element elementID] length] == 0) return NO;
	
	id <XMPPTrackingInfo> info = [dict objectForKey:[element elementID]];
    
    if(info)
    {
        BOOL valid = YES;
            
        if(xmppStream && [element isKindOfClass:[XMPPIQ class]] && [[info element] isKindOfClass:[XMPPIQ class]])
        {
            XMPPIQ *iq = (XMPPIQ *)element;
            
            if([iq isResultIQ] || [iq isErrorIQ])
            {
                valid = [xmppStream isValidResponseElement:iq forRequestElement:[info element]];
            }
        }
        
        if(!valid)
        {
            XMPPLogError(@"%s: Element with ID %@ cannot be validated.", __FILE__ , [element elementID]);
        }
        
        if (valid)
        {
            [info invokeWithObject:obj];
            [info cancelTimer];
            [dict removeObjectForKey:[element elementID]];
            
            return YES;
        }
    }
	
	return NO;
}

- (NSUInteger)numberOfIDs
{
    AssertProperQueue();
	
	return [[dict allKeys] count];
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
@synthesize element;

- (id)init
{
	// Use initWithTarget:selector:timeout: or initWithBlock:timeout:
	
	return nil;
}

- (id)initWithTarget:(id)aTarget selector:(SEL)aSelector timeout:(NSTimeInterval)aTimeout
{
    if(target || selector)
    {
        NSParameterAssert(aTarget);
        NSParameterAssert(aSelector);
    }
	
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
		#if !OS_OBJECT_USE_OBJC
		dispatch_release(timer);
		#endif
		timer = NULL;
	}
}

- (void)invokeWithObject:(id)obj
{
	if (block)
    {
		block(obj, self);
	}
    else if(target && selector)
	{
		#pragma clang diagnostic push
		#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
		[target performSelector:selector withObject:obj withObject:self];
		#pragma clang diagnostic pop
	}
}

@end
