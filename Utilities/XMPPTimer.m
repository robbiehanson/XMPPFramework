#import "XMPPTimer.h"
#import "XMPPLogging.h"

// Log levels: off, error, warn, info, verbose
// Log flags: trace
#if DEBUG
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#else
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

@implementation XMPPTimer
{
	BOOL isStarted;
	
	dispatch_time_t start;
	uint64_t timeout;
	uint64_t interval;
	
	dispatch_source_t timer;
}

- (instancetype)initWithQueue:(dispatch_queue_t)queue eventHandler:(dispatch_block_t)block
{
	if ((self = [super init]))
	{
		timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
		dispatch_source_set_event_handler(timer, block);
		
		isStarted = NO;
	}
	return self;
}

- (void)dealloc
{
	[self cancel];
}

- (void)startWithTimeout:(NSTimeInterval)inTimeout interval:(NSTimeInterval)inInterval
{
	if (isStarted)
	{
		XMPPLogWarn(@"Unable to start timer - already started");
		return;
	}
	
	start = dispatch_time(DISPATCH_TIME_NOW, 0);
	timeout = (inTimeout * NSEC_PER_SEC);
	interval = (inInterval > 0.0) ? (inInterval * NSEC_PER_SEC) : DISPATCH_TIME_FOREVER;
	
	dispatch_source_set_timer(timer, dispatch_time(start, timeout), interval, 0);
	dispatch_resume(timer);
	
	isStarted = YES;
}

- (void)updateTimeout:(NSTimeInterval)inTimeout fromOriginalStartTime:(BOOL)useOriginalStartTime
{
	if (!isStarted)
	{
		XMPPLogWarn(@"Unable to update timer - not yet started");
		return;
	}
	
	if (!useOriginalStartTime) {
		start = dispatch_time(DISPATCH_TIME_NOW, 0);
	}
	timeout = (inTimeout * NSEC_PER_SEC);
	
	dispatch_source_set_timer(timer, dispatch_time(start, timeout), interval, 0);
}

- (void)cancel
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

@end
