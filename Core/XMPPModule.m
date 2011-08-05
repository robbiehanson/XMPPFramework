#import "XMPPModule.h"
#import "XMPPStream.h"
#import "XMPPLogging.h"

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
	if (xmppStream)
	{
		// It is dangerous to rely on the dealloc method to deactivate a module.
		// 
		// Why?
		// Because when a module is activated, it is added as a delegate to the xmpp stream.
		// In addition to this, the module may be added as a delegate to various other xmpp components.
		// As per usual, these delegate references do NOT retain this module.
		// This means that modules may get invoked after they are deallocated.
		// 
		// Consider the following example:
		// 
		// 1. Thread A: Module is created (alloc/init) (retainCount = 1)
		// 2. Thread A: Module is activated (retainCount = 1)
		// 3. Thread A: Module is released, and dealloc is called.
		//              First [MyCustomModule dealloc] is invoked.
		//              Then [XMPPModule dealloc] is invoked.
		//              Only at this point is [XMPPModule deactivate] run.
		//              Since the deactivate method is synchronous,
		//              it blocks until the module is removed as a delegate from the stream and all other modules.
		// 4. Thread B: Invokes a delegate method on our module ([XMPPModule deactivate] is waiting on thread B).
		// 5. Thread A: The [XMPPModule deactivate] method returns, but the damage is done.
		//              Thread B has asynchronously dispatched a delegate method set to run on our module.
		// 6. Thread A: The dealloc method completes, and our module is now deallocated.
		// 7. Thread C: The delegate method attempts to run on our module, which is deallocated,
		//              the application crashes, the computer blows up, and a meteor hits your favorite restaurant.
		
		XMPPLogWarn(@"%@: Deallocating activated module. You should deactivate modules before their final release.",
		              NSStringFromClass([self class]));
		
		[self deactivate];
	}
	
	[multicastDelegate release];
	
	dispatch_release(moduleQueue);
	
	[super dealloc];
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
			xmppStream = [aXmppStream retain];
			
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
			
			[xmppStream release];
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
	if (dispatch_get_current_queue() == moduleQueue)
	{
		return moduleQueue;
	}
	else
	{
		__block dispatch_queue_t result;
		
		dispatch_sync(moduleQueue, ^{
			result = moduleQueue;
		});
		
		return result;
	}
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
			result = [xmppStream retain];
		});
		
		return [result autorelease];
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
	// Override me to provide a proper module name.
	// The name may be used as the name of the dispatch_queue which could aid in debugging.
	
	return @"XMPPModule";
}

@end
