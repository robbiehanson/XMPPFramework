#import "MulticastDelegate.h"

/**
 * How does this class work?
 * 
 * In theory, this class is very straight-forward.
 * It provides a way for multiple delegates to be called.
 * So any delegate method call to this class will get forwarded to each delegate in the list.
 * 
 * In practice it's fairly easy as well, but there are two small complications.
 * 
 * Complication 1:
 * A class must not retain its delegate.
 * That is, if you call [client setDelegate:self], "client" should NOT be retaining "self".
 * This means we should avoid storing all the delegates in an NSArray, or other such class that retains its objects.
 * 
 * Complication 2:
 * A delegate must be allowed to add/remove itself at any time.
 * This includes removing itself in the middle of a delegate callback without any unintended complications.
 * 
 * We solve these complications by using a simple linked list.
**/

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation MulticastDelegate

void MulticastDelegateListNodeRetain(MulticastDelegateListNode *node)
{
    node->retainCount++;
}

void MulticastDelegateListNodeRelease(MulticastDelegateListNode *node)
{
    node->retainCount--;
    
    if(node->retainCount == 0)
    {
        free(node);
    }
}

- (id)init
{
	if((self = [super init]))
	{
		currentInvocationIndex = 0;
	}
	return self;
}

- (void)addDelegate:(id)delegate
{
	MulticastDelegateListNode *node = malloc(sizeof(node));
    node->delegate = delegate;
    node->retainCount = 1;
	
	// Remember: The delegateList is a linked list of MulticastDelegateListNode objects.
	// Each node object is allocated and placed in the list.
	// It is not deallocated until it is later removed from the linked list.
	
	if(delegateList != nil)
	{
        node->prev = nil;
		node->next = delegateList;
		node->next->prev = node;
	}
    else
    {
        node->prev = nil;
        node->next = nil;
    }
	
	delegateList = node;
}

- (void)removeDelegate:(id)delegate
{
	MulticastDelegateListNode *node = delegateList;
	NSUInteger nodeIndex = 0;
	
	while(node != nil)
	{
		if(delegate == node->delegate)
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
            
			if(node->prev != nil)
				node->prev->next = node->next;
			else
				delegateList = node->next;
			
			if(node->next != nil)
				node->next->prev = node->prev;
			
			// We do NOT change the prev/next pointers of the node.
			// If it's in use within forwardInvocation, these pointers are still needed.
			// However, if multiple delegates are removed in the middle of a delegate callback,
			// we still need to be sure not to invoke any delegates that were removed.
            
            node->delegate = nil;
            MulticastDelegateListNodeRelease(node);
			
			if(nodeIndex < currentInvocationIndex)
			{
				currentInvocationIndex--;
			}
			break;
		}
		
		nodeIndex++;
		node = node->next;
	}
}

- (void)removeAllDelegates
{
	MulticastDelegateListNode *node = delegateList;
	
	while(node != nil)
	{
		MulticastDelegateListNode *next = node->next;
		
		node->prev = nil;
		node->next = nil;
		
        MulticastDelegateListNodeRelease(node);
		
		node = next;
	}
	
	currentInvocationIndex = 0;
	delegateList = nil;
}

- (NSUInteger)count
{
	NSUInteger count = 0;
	
	MulticastDelegateListNode *node;
	for(node = delegateList; node != nil; node = node->next)
	{
		count++;
	}
	
	return count;
}

/**
 * Forwarding fast path.
 * Available in 10.5+ (Not properly declared in NSOject until 10.6)
**/
- (id)forwardingTargetForSelector:(SEL)aSelector
{
	// We can take advantage of this if we only have one delegate (a common case),
	// or simply one delegate that responds to this selector.
	
	MulticastDelegateListNode *foundNode = nil;
	
	MulticastDelegateListNode *node = delegateList;
	while(node)
	{
		if([node->delegate respondsToSelector:aSelector])
		{
			if(foundNode)
			{
				// There are multiple delegates for this selector.
				// We can't take advantage of the forwarding fast path.
				return nil;
			}
			
			foundNode = node;
		}
		
		node = node->next;
	}
	
	if(foundNode)
	{
		return foundNode->delegate;
	}
	
	return nil;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
	MulticastDelegateListNode *node;
	for(node = delegateList; node != nil; node = node->next)
	{
		NSMethodSignature *result = [node->delegate methodSignatureForSelector:aSelector];
		
		if(result != nil)
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

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	// Here are the rules:
	// If a delegate is added during this method, it should NOT be invoked.
	// If a delegate is removed during this method that has not already been invoked, it should NOT be invoked.
	// 
	// The first rule is the reason for the currentInvocationIndex variable.
	
	MulticastDelegateListNode *node = delegateList;
	currentInvocationIndex = 0;
	
	// First we loop through the linked list so we can:
	// - Get a count of the number of delegates
	// - Get a reference to the last delegate in the list
	// 
	// Recall that new delegates are added to the beginning of the linked list.
	// The last delegate in the list is the first delegate that was added, so it will be the first that's invoked.
	// We're going to be moving backwards through the linked list as we invoke the delegates.
	// 
	// The currentInvocationIndex variable prevents us from invoking a delegate that
	// was added in the middle of our invocation loop below.
	
	while(node->next != nil)
	{
		node = node->next;
		currentInvocationIndex++;
	}
	
	while(node != nil)
	{
		// Retain the node before we invoke the delegate.
		// We do this because the delegate might remove itself from the delegate list within the invoked method.
		// And we don't want to get the previous node now, because it may also be
		// removed from the list within the invoked method.
		MulticastDelegateListNodeRetain(node);
		
		if([node->delegate respondsToSelector:[anInvocation selector]])
		{
			[anInvocation invokeWithTarget:node->delegate];
		}
		
		node = node->prev;
		if(currentInvocationIndex > 0)
			currentInvocationIndex--;
		else
			break;
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

@end
