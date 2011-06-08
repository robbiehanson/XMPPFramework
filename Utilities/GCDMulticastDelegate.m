#import "GCDMulticastDelegate.h"
#import <libkern/OSAtomic.h>

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

@interface GCDMulticastDelegate (PrivateAPI)

- (NSInvocation *)duplicateInvocation:(NSInvocation *)origInvocation;

@end

@interface GCDMulticastDelegateEnumerator (PrivateAPI)

- (id)initWithDelegateList:(GCDMulticastDelegateListNode *)delegateList;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

static void GCDMulticastDelegateListNodeRetain(GCDMulticastDelegateListNode *node)
{
	OSAtomicIncrement32Barrier(&node->retainCount);
}

static void GCDMulticastDelegateListNodeRelease(GCDMulticastDelegateListNode *node)
{
	int32_t newRetainCount = OSAtomicDecrement32Barrier(&node->retainCount);
    if (newRetainCount == 0)
    {
        free(node);
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation GCDMulticastDelegate

- (id)init
{
	if ((self = [super init]))
	{
		delegateList = NULL;
	}
	return self;
}

- (void)addDelegate:(id)delegate delegateQueue:(dispatch_queue_t)delegateQueue
{
	if (delegate == nil) return;
	if (delegateQueue == NULL) return;
	
	GCDMulticastDelegateListNode *node = malloc(sizeof(GCDMulticastDelegateListNode));
	
    node->delegate = delegate;
	node->delegateQueue = delegateQueue;
    node->retainCount = 1;
	
	dispatch_retain(delegateQueue);
	
	// Remember: The delegateList is a linked list of MulticastDelegateListNode objects.
	// Each node object is allocated and placed in the list.
	// It is not deallocated until it is later removed from the linked list.
	
	if (delegateList == NULL)
	{
		node->prev = NULL;
        node->next = NULL;
	}
    else
    {
        node->prev = NULL;
		node->next = delegateList;
		node->next->prev = node;
    }
	
	delegateList = node;
}

- (void)removeDelegate:(id)delegate delegateQueue:(dispatch_queue_t)delegateQueue
{
	if (delegate == nil) return;
	
	GCDMulticastDelegateListNode *node = delegateList;
	while (node != NULL)
	{
		if (delegate == node->delegate)
		{
			if ((delegateQueue == NULL) || (delegateQueue == node->delegateQueue))
			{
				// Remove the node from the list.
				// This is done by editing the pointers of the node's neighbors to skip it.
				// 
				// In other words:
				// node->prev->next = node->next
				// node->next->prev = node->prev
				// 
				// We also want to properly update our delegateList pointer,
				// which always points to the "first" element in the list. (Most recently added.)
				
				if(node->prev != NULL)
					node->prev->next = node->next;
				else
					delegateList = node->next;
				
				if(node->next != NULL)
					node->next->prev = node->prev;
				
				node->prev = NULL;
				node->next = NULL;
				
				dispatch_release(node->delegateQueue);
				
				node->delegate = nil;
				node->delegateQueue = NULL;
				
				GCDMulticastDelegateListNodeRelease(node);
				
				break;
			}
		}
		else
		{
			node = node->next;
		}
	}
}

- (void)removeDelegate:(id)delegate
{
	[self removeDelegate:delegate delegateQueue:NULL];
}

- (void)removeAllDelegates
{
	GCDMulticastDelegateListNode *node = delegateList;
	
	while (node != NULL)
	{
		GCDMulticastDelegateListNode *next = node->next;
		
		node->prev = NULL;
		node->next = NULL;
		
		dispatch_release(node->delegateQueue);
		
		node->delegate = nil;
		node->delegateQueue = NULL;
		
        GCDMulticastDelegateListNodeRelease(node);
		
		node = next;
	}
	
	delegateList = NULL;
}

- (NSUInteger)count
{
	NSUInteger count = 0;
	
	GCDMulticastDelegateListNode *node;
	for (node = delegateList; node != NULL; node = node->next)
	{
		count++;
	}
	
	return count;
}

- (NSUInteger)countOfClass:(Class)aClass
{
	NSUInteger count = 0;
	
	GCDMulticastDelegateListNode *node;
	for (node = delegateList; node != NULL; node = node->next)
	{
		if ([node->delegate isKindOfClass:aClass])
		{
			count++;
		}
	}
	
	return count;
}

- (NSUInteger)countForSelector:(SEL)aSelector
{
	NSUInteger count = 0;
	
	GCDMulticastDelegateListNode *node;
	for (node = delegateList; node != NULL; node = node->next)
	{
		if ([node->delegate respondsToSelector:aSelector])
		{
			count++;
		}
	}
	
	return count;
}

- (GCDMulticastDelegateEnumerator *)delegateEnumerator
{
	return [[[GCDMulticastDelegateEnumerator alloc] initWithDelegateList:delegateList] autorelease];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
	GCDMulticastDelegateListNode *node;
	for (node = delegateList; node != NULL; node = node->next)
	{
		NSMethodSignature *result = [node->delegate methodSignatureForSelector:aSelector];
		
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
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	// All delegates MUST be invoked ASYNCHRONOUSLY.
	
	GCDMulticastDelegateListNode *node = delegateList;
	
	if (node != NULL)
	{
		// Recall that new delegates are added to the beginning of the linked list.
		// The last delegate in the list is the first delegate that was added, so it will be the first that's invoked.
		// We're going to be moving backwards through the linked list as we invoke the delegates.
		// 
		// Loop through the linked list so we can get a reference to the last delegate in the list.
		
		while (node->next != NULL)
		{
			node = node->next;
		}
		
		SEL selector = [origInvocation selector];
		
		while (node != NULL)
		{
			id delegate = node->delegate;
			
			if ([delegate respondsToSelector:selector])
			{
				NSInvocation *dupInvocation = [self duplicateInvocation:origInvocation];
				
				dispatch_async(node->delegateQueue, ^{
					NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
					
					[dupInvocation invokeWithTarget:delegate];
					
					[pool drain];
				});
			}
			
			node = node->prev;
		}
	}
	
	[pool release];
}

- (void)doesNotRecognizeSelector:(SEL)aSelector
{
	// Prevent NSInvalidArgumentException
}

- (void)doNothing {}

- (void)dealloc
{
	[self removeAllDelegates];
	[super dealloc];
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
			id value;
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

@implementation GCDMulticastDelegateEnumerator

- (id)initWithDelegateList:(GCDMulticastDelegateListNode *)delegateList
{
	if ((self = [super init]))
	{
		numDelegates = 0;
		currentDelegateIndex = 0;
		
		// The delegate enumerator will provide a snapshot of the current delegate list.
		// 
		// So, technically, delegates could be added/removed from the list while we're enumerating.
		
		GCDMulticastDelegateListNode *node = delegateList;
		
		// First we loop through the linked list so we can:
		// 
		// - Get a count of the number of delegates
		// - Get a reference to the last delegate in the list
		// 
		// Recall that new delegates are added to the beginning of the linked list.
		// The last delegate in the list is the first delegate that was added, so it will be the first that's invoked.
		// We're going to be moving backwards through the linked list as we add the delegates to our array.
		
		if (node != NULL)
		{
			numDelegates++;
			
			while (node->next != NULL)
			{
				numDelegates++;
				node = node->next;
			}
			
			// Note: The node variable is now pointing to the last node in the list.
		}
		
		// We're now going to create an array of all the nodes.
		// 
		// Note: We're creating an array of pointers.
		// Each pointer points to the dynamically allocated struct.
		// We also retain each node, to prevent it from disappearing while we're enumerating the list.
		
		size_t ptrSize = sizeof(node);
		
		delegates = malloc(ptrSize * numDelegates);
		
		// Remember that delegates is a pointer to an array of pointers.
		// It's going to look something like this in memory:
		// 
		// delegates ---> |ptr1|ptr2|ptr3|...|
		// 
		// So delegates points to ptr1.
		// And due to pointer arithmetic, delegates+1 points to ptr2.
		
		NSUInteger i;
		for (i = 0; i < numDelegates; i++)
		{
			memcpy(delegates + i, &node, ptrSize);
			GCDMulticastDelegateListNodeRetain(node);
			
			node = node->prev;
		}
	}
	return self;
}

- (NSUInteger)count
{
	return numDelegates;
}

- (NSUInteger)countOfClass:(Class)aClass
{
	NSUInteger count = 0;
	NSUInteger index = 0;
	
	while (index < numDelegates)
	{
		GCDMulticastDelegateListNode *node = *(delegates + index);
		
		if ([node->delegate isKindOfClass:aClass])
		{
			count++;
		}
		
		index++;
	}
	
	return count;
}

- (NSUInteger)countForSelector:(SEL)aSelector
{
	NSUInteger count = 0;
	NSUInteger index = 0;
	
	while (index < numDelegates)
	{
		GCDMulticastDelegateListNode *node = *(delegates + index);
		
		if ([node->delegate respondsToSelector:aSelector])
		{
			count++;
		}
		
		index++;
	}
	
	return count;
}

- (BOOL)getNextDelegate:(id *)delPtr delegateQueue:(dispatch_queue_t *)dqPtr
{
	while (currentDelegateIndex < numDelegates)
	{
		GCDMulticastDelegateListNode *node = *(delegates + currentDelegateIndex);
		currentDelegateIndex++;
		
		if (node->delegate)
		{
			if (delPtr) *delPtr = node->delegate;
			if (dqPtr)  *dqPtr  = node->delegateQueue;
			
			return YES;
		}
	}
	
	return NO;
}

- (BOOL)getNextDelegate:(id *)delPtr delegateQueue:(dispatch_queue_t *)dqPtr ofClass:(Class)aClass
{
	while (currentDelegateIndex < numDelegates)
	{
		GCDMulticastDelegateListNode *node = *(delegates + currentDelegateIndex);
		currentDelegateIndex++;
		
		if ([node->delegate isKindOfClass:aClass])
		{
			if (delPtr) *delPtr = node->delegate;
			if (dqPtr)  *dqPtr  = node->delegateQueue;
			
			return YES;
		}
	}
	
	return NO;
}

- (BOOL)getNextDelegate:(id *)delPtr delegateQueue:(dispatch_queue_t *)dqPtr forSelector:(SEL)aSelector
{
	while (currentDelegateIndex < numDelegates)
	{
		GCDMulticastDelegateListNode *node = *(delegates + currentDelegateIndex);
		currentDelegateIndex++;
		
		if ([node->delegate respondsToSelector:aSelector])
		{
			if (delPtr) *delPtr = node->delegate;
			if (dqPtr)  *dqPtr  = node->delegateQueue;
			
			return YES;
		}
	}
	
	return NO;
}

- (void)dealloc
{
	NSUInteger i;
	for (i = 0; i < numDelegates; i++)
	{
		GCDMulticastDelegateListNode *node = *(delegates + i);
		GCDMulticastDelegateListNodeRelease(node);
	}
	
	free(delegates);
	
	[super dealloc];
}

@end
