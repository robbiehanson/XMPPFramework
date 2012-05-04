#import "XMPPModule.h"
#import "XMPPStream.h"
#import "XMPPLogging.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

// Log levels: off, error, warn, info, verbose
#if DEBUG
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#else
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif


@implementation XMPPModule

/**
 * Standard init method.
**/
- (id)init
{
	return [self initWithDispatchQueue:NULL];
}

/**
 * Designated initializer.
**/
- (id)initWithDispatchQueue:(dispatch_queue_t)queue
{
	if ((self = [super init]))
	{
		if (queue)
		{
			moduleQueue = queue;
			dispatch_retain(moduleQueue);
		}
		else
		{
			const char *moduleQueueName = [[self moduleName] UTF8String];
			moduleQueue = dispatch_queue_create(moduleQueueName, NULL);
		}
		
		multicastDelegate = [[GCDMulticastDelegate alloc] init];
	}
	return self;
}

- (void)dealloc
{
	dispatch_release(moduleQueue);
}

/**
 * The activate method is the point at which the module gets plugged into the xmpp stream.
 * Subclasses may override this method to perform any custom actions,
 * but must invoke [super activate:aXmppStream] at some point within their implementation.
**/
- (BOOL)activate:(XMPPStream *)aXmppStream
{
	__block BOOL result = YES;
	
	dispatch_block_t block = ^{
		
		if (xmppStream != nil)
		{
			result = NO;
		}
		else
		{
			xmppStream = aXmppStream;
			
			[xmppStream addDelegate:self delegateQueue:moduleQueue];
			[xmppStream registerModule:self];
		}
	};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_sync(moduleQueue, block);
	
	return result;
}

/**
 * The deactivate method unplugs a module from the xmpp stream.
 * When this method returns, no further delegate methods on this module will be dispatched.
 * However, there may be delegate methods that have already been dispatched.
 * If this is the case, the module will be properly retained until the delegate methods have completed.
 * If your custom module requires that delegate methods are not run after the deactivate method has been run,
 * then simply check the xmppStream variable in your delegate methods.
**/
- (void)deactivate
{
	dispatch_block_t block = ^{
		
		if (xmppStream)
		{
			[xmppStream removeDelegate:self delegateQueue:moduleQueue];
			[xmppStream unregisterModule:self];
			
			xmppStream = nil;
		}
	};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_sync(moduleQueue, block);
}

- (dispatch_queue_t)moduleQueue
{
	return moduleQueue;
}

- (XMPPStream *)xmppStream
{
	if (dispatch_get_current_queue() == moduleQueue)
	{
		return xmppStream;
	}
	else
	{
		__block XMPPStream *result;
		
		dispatch_sync(moduleQueue, ^{
			result = xmppStream;
		});
		
		return result;
	}
}

- (void)addDelegate:(id)delegate delegateQueue:(dispatch_queue_t)delegateQueue
{
	// Asynchronous operation (if outside xmppQueue)
	
	dispatch_block_t block = ^{
		[multicastDelegate addDelegate:delegate delegateQueue:delegateQueue];
	};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (void)removeDelegate:(id)delegate delegateQueue:(dispatch_queue_t)delegateQueue
{
	// Synchronous operation
	// 
	// Delegate removal MUST always be synchronous.
	
	dispatch_block_t block = ^{
		[multicastDelegate removeDelegate:delegate delegateQueue:delegateQueue];
	};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_sync(moduleQueue, block);
}

- (void)removeDelegate:(id)delegate
{
	// Synchronous operation
	// 
	// Delegate remove MUST always be synchronous.
	
	dispatch_block_t block = ^{
		[multicastDelegate removeDelegate:delegate];
	};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_sync(moduleQueue, block);
}

- (NSString *)moduleName
{
	// Override me (if needed) to provide a customized module name.
	// This name is used as the name of the dispatch_queue which could aid in debugging.
	
	return NSStringFromClass([self class]);
}

@end
