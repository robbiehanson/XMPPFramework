#import "GCDMulticastDelegate.h"
#import <libkern/OSAtomic.h>

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

/**
 * How does this class work?
 * 
 * In theory, this class is very straight-forward.
 * It provides a way for multiple delegates to be called, each on its own delegate queue.
 * 
 * In other words, any delegate method call to this class
 * will get forwarded (dispatch_async'd) to each added delegate.
 * 
 * Important note concerning thread-safety:
 * 
 * This class is designed to be used from within a single dispatch queue.
 * In other words, it is NOT thread-safe, and should only be used from within the external dedicated dispatch_queue.
**/

@interface GCDMulticastDelegateNode : NSObject
{
  #if __has_feature(objc_arc_weak)
	__weak id delegate;
  #else
	__unsafe_unretained id delegate;
  #endif
	
	dispatch_queue_t delegateQueue;
}

- (id)initWithDelegate:(id)delegate delegateQueue:(dispatch_queue_t)delegateQueue;

#if __has_feature(objc_arc_weak)
@property (/* atomic */ readwrite, weak) id delegate;
#else
@property (/* atomic */ readwrite, unsafe_unretained) id delegate;
#endif

@property (nonatomic, readonly) dispatch_queue_t delegateQueue;

@end


@interface GCDMulticastDelegate ()
{
	NSMutableArray *delegateNodes;
}

- (NSInvocation *)duplicateInvocation:(NSInvocation *)origInvocation;

@end


@interface GCDMulticastDelegateEnumerator ()
{
	NSUInteger numNodes;
	NSUInteger currentNodeIndex;
	NSArray *delegateNodes;
}

- (id)initFromDelegateNodes:(NSMutableArray *)inDelegateNodes;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation GCDMulticastDelegate

- (id)init
{
	if ((self = [super init]))
	{
		delegateNodes = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void)addDelegate:(id)delegate delegateQueue:(dispatch_queue_t)delegateQueue
{
	if (delegate == nil) return;
	if (delegateQueue == NULL) return;
	
	GCDMulticastDelegateNode *node =
	    [[GCDMulticastDelegateNode alloc] initWithDelegate:delegate delegateQueue:delegateQueue];
	
	[delegateNodes addObject:node];
}

- (void)removeDelegate:(id)delegate delegateQueue:(dispatch_queue_t)delegateQueue
{
	if (delegate == nil) return;
	
	NSUInteger i;
	for (i = [delegateNodes count]; i > 0; i--)
	{
		GCDMulticastDelegateNode *node = [delegateNodes objectAtIndex:(i-1)];
		
		if (delegate == node.delegate)
		{
			if ((delegateQueue == NULL) || (delegateQueue == node.delegateQueue))
			{
				// Recall that this node may be retained by a GCDMulticastDelegateEnumerator.
				// The enumerator is a thread-safe snapshot of the delegate list at the moment it was created.
				// To properly remove this node from list, and from the list(s) of any enumerators,
				// we nullify the delegate via the atomic property.
				// 
				// However, the delegateQueue is not modified.
				// The thread-safety is hinged on the atomic delegate property.
				// The delegateQueue is expected to properly exist until the node is deallocated.
				
				node.delegate = nil;
				
				[delegateNodes removeObjectAtIndex:(i-1)];
			}
		}
	}
}

- (void)removeDelegate:(id)delegate
{
	[self removeDelegate:delegate delegateQueue:NULL];
}

- (void)removeAllDelegates
{
	for (GCDMulticastDelegateNode *node in delegateNodes)
	{
		node.delegate = nil;
	}
	
	[delegateNodes removeAllObjects];
}

- (NSUInteger)count
{
	return [delegateNodes count];
}

- (NSUInteger)countOfClass:(Class)aClass
{
	NSUInteger count = 0;
	
	for (GCDMulticastDelegateNode *node in delegateNodes)
	{
		if ([node.delegate isKindOfClass:aClass])
		{
			count++;
		}
	}
	
	return count;
}

- (NSUInteger)countForSelector:(SEL)aSelector
{
	NSUInteger count = 0;
	
	for (GCDMulticastDelegateNode *node in delegateNodes)
	{
		if ([node.delegate respondsToSelector:aSelector])
		{
			count++;
		}
	}
	
	return count;
}

- (GCDMulticastDelegateEnumerator *)delegateEnumerator
{
	return [[GCDMulticastDelegateEnumerator alloc] initFromDelegateNodes:delegateNodes];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
	for (GCDMulticastDelegateNode *node in delegateNodes)
	{
		NSMethodSignature *result = [node.delegate methodSignatureForSelector:aSelector];
		
		if (result != nil)
		{
			return result;
		}
	}
	
	// This causes a crash...
	// return [super methodSignatureForSelector:aSelector];
	
	// This also causes a crash...
	// return nil;
	
	return [[self class] instanceMethodSignatureForSelector:@selector(doNothing)];
}

- (void)forwardInvocation:(NSInvocation *)origInvocation
{
	SEL selector = [origInvocation selector];
	BOOL foundNilDelegate = NO;
	
	for (GCDMulticastDelegateNode *node in delegateNodes)
	{
		id delegate = node.delegate;
		
		if ([delegate respondsToSelector:selector])
		{
			// All delegates MUST be invoked ASYNCHRONOUSLY.
			
			NSInvocation *dupInvocation = [self duplicateInvocation:origInvocation];
			
			dispatch_async(node.delegateQueue, ^{ @autoreleasepool {
				
				[dupInvocation invokeWithTarget:delegate];
				
			}});
		}
		else if (delegate == nil)
		{
			foundNilDelegate = YES;
		}
	}
	
	if (foundNilDelegate)
	{
		// At lease one weak delegate reference disappeared.
		// Remove nil delegate nodes from the list.
		// 
		// This is expected to happen very infrequently.
		// This is why we handle it separately (as it requires allocating an indexSet).
		
		NSMutableIndexSet *indexSet = [[NSMutableIndexSet alloc] init];
		
		NSUInteger i = 0;
		for (GCDMulticastDelegateNode *node in delegateNodes)
		{
			if (node.delegate == nil)
			{
				[indexSet addIndex:i];
			}
			i++;
		}
		
		[delegateNodes removeObjectsAtIndexes:indexSet];
	}
}

- (void)doesNotRecognizeSelector:(SEL)aSelector
{
	// Prevent NSInvalidArgumentException
}

- (void)doNothing {}

- (void)dealloc
{
	[self removeAllDelegates];
}

- (NSInvocation *)duplicateInvocation:(NSInvocation *)origInvocation
{
	NSMethodSignature *methodSignature = [origInvocation methodSignature];
	
	NSInvocation *dupInvocation = [NSInvocation invocationWithMethodSignature:methodSignature];
	[dupInvocation setSelector:[origInvocation selector]];
	
	NSUInteger i, count = [methodSignature numberOfArguments];
	for (i = 2; i < count; i++)
	{
		const char *type = [methodSignature getArgumentTypeAtIndex:i];
		
		if (*type == *@encode(BOOL))
		{
			BOOL value;
			[origInvocation getArgument:&value atIndex:i];
			[dupInvocation setArgument:&value atIndex:i];
		}
		else if (*type == *@encode(char) || *type == *@encode(unsigned char))
		{
			char value;
			[origInvocation getArgument:&value atIndex:i];
			[dupInvocation setArgument:&value atIndex:i];
		}
		else if (*type == *@encode(short) || *type == *@encode(unsigned short))
		{
			short value;
			[origInvocation getArgument:&value atIndex:i];
			[dupInvocation setArgument:&value atIndex:i];
		}
		else if (*type == *@encode(int) || *type == *@encode(unsigned int))
		{
			int value;
			[origInvocation getArgument:&value atIndex:i];
			[dupInvocation setArgument:&value atIndex:i];
		}
		else if (*type == *@encode(long) || *type == *@encode(unsigned long))
		{
			long value;
			[origInvocation getArgument:&value atIndex:i];
			[dupInvocation setArgument:&value atIndex:i];
		}
		else if (*type == *@encode(long long) || *type == *@encode(unsigned long long))
		{
			long long value;
			[origInvocation getArgument:&value atIndex:i];
			[dupInvocation setArgument:&value atIndex:i];
		}
		else if (*type == *@encode(double))
		{
			double value;
			[origInvocation getArgument:&value atIndex:i];
			[dupInvocation setArgument:&value atIndex:i];
		}
		else if (*type == *@encode(float))
		{
			float value;
			[origInvocation getArgument:&value atIndex:i];
			[dupInvocation setArgument:&value atIndex:i];
		}
		else if (*type == '@')
		{
			void *value;
			[origInvocation getArgument:&value atIndex:i];
			[dupInvocation setArgument:&value atIndex:i];
		}
		else
		{
			NSString *selectorStr = NSStringFromSelector([origInvocation selector]);
			
			NSString *format = @"Argument %lu to method %@ - Type(%c) not supported";
			NSString *reason = [NSString stringWithFormat:format, (unsigned long)(i - 2), selectorStr, *type];
			
			[[NSException exceptionWithName:NSInvalidArgumentException reason:reason userInfo:nil] raise];
		}
	}
	
	[dupInvocation retainArguments];
	
	return dupInvocation;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation GCDMulticastDelegateNode

@synthesize delegate;      // atomic
@synthesize delegateQueue; // non-atomic

- (id)initWithDelegate:(id)inDelegate delegateQueue:(dispatch_queue_t)inDelegateQueue
{
	if ((self = [super init]))
	{
		delegate = inDelegate;
		delegateQueue = inDelegateQueue;
		
		if (delegateQueue)
			dispatch_retain(delegateQueue);
	}
	return self;
}

- (void)dealloc
{
	if (delegateQueue)
		dispatch_release(delegateQueue);
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation GCDMulticastDelegateEnumerator

- (id)initFromDelegateNodes:(NSMutableArray *)inDelegateNodes
{
	if ((self = [super init]))
	{
		delegateNodes = [inDelegateNodes copy];
		
		numNodes = [delegateNodes count];
		currentNodeIndex = 0;
	}
	return self;
}

- (NSUInteger)count
{
	return numNodes;
}

- (NSUInteger)countOfClass:(Class)aClass
{
	NSUInteger count = 0;
	
	for (GCDMulticastDelegateNode *node in delegateNodes)
	{
		if ([node.delegate isKindOfClass:aClass])
		{
			count++;
		}
	}
	
	return count;
}

- (NSUInteger)countForSelector:(SEL)aSelector
{
	NSUInteger count = 0;
	
	for (GCDMulticastDelegateNode *node in delegateNodes)
	{
		if ([node.delegate respondsToSelector:aSelector])
		{
			count++;
		}
	}
	
	return count;
}

- (BOOL)getNextDelegate:(id *)delPtr delegateQueue:(dispatch_queue_t *)dqPtr
{
	while (currentNodeIndex < numNodes)
	{
		GCDMulticastDelegateNode *node = [delegateNodes objectAtIndex:currentNodeIndex];
		currentNodeIndex++;
		
		id nodeDelegate = node.delegate; // snapshot atomic property
		if (nodeDelegate)
		{
			if (delPtr) *delPtr = nodeDelegate;
			if (dqPtr)  *dqPtr  = node.delegateQueue;
			
			return YES;
		}
	}
	
	return NO;
}

- (BOOL)getNextDelegate:(id *)delPtr delegateQueue:(dispatch_queue_t *)dqPtr ofClass:(Class)aClass
{
	while (currentNodeIndex < numNodes)
	{
		GCDMulticastDelegateNode *node = [delegateNodes objectAtIndex:currentNodeIndex];
		currentNodeIndex++;
		
		id nodeDelegate = node.delegate; // snapshot atomic property
		if ([nodeDelegate isKindOfClass:aClass])
		{
			if (delPtr) *delPtr = nodeDelegate;
			if (dqPtr)  *dqPtr  = node.delegateQueue;
			
			return YES;
		}
	}
	
	return NO;
}

- (BOOL)getNextDelegate:(id *)delPtr delegateQueue:(dispatch_queue_t *)dqPtr forSelector:(SEL)aSelector
{
	while (currentNodeIndex < numNodes)
	{
		GCDMulticastDelegateNode *node = [delegateNodes objectAtIndex:currentNodeIndex];
		currentNodeIndex++;
		
		id nodeDelegate = node.delegate; // snapshot atomic property
		if ([nodeDelegate respondsToSelector:aSelector])
		{
			if (delPtr) *delPtr = nodeDelegate;
			if (dqPtr)  *dqPtr  = node.delegateQueue;
			
			return YES;
		}
	}
	
	return NO;
}

@end
