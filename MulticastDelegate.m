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
 * This means we should avoid storing all the delegates in an NSArray,
 * or any other such class that retains its objects.
 * 
 * Complication 2:
 * A delegate must be allowed to add/remove itself at any time.
 * This includes removing itself in the middle of a delegate callback without any unintended complications.
 * 
 * We solve these complications by using a simple linked list.
**/

@interface MulticastDelegateEnumerator (PrivateAPI)

- (id)initWithDelegateList:(MulticastDelegateListNode *)delegateList;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

static void MulticastDelegateListNodeRetain(MulticastDelegateListNode *node)
{
    node->retainCount++;
}

static void MulticastDelegateListNodeRelease(MulticastDelegateListNode *node)
{
    node->retainCount--;
    
    if(node->retainCount == 0)
    {
        free(node);
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation MulticastDelegate

- (id)init
{
	if((self = [super init]))
	{
		delegateList = NULL;
	}
	return self;
}

- (void)addDelegate:(id)delegate
{
	if(delegate == nil) return;
	
	MulticastDelegateListNode *node = malloc(sizeof(MulticastDelegateListNode));
	
    node->delegate = delegate;
    node->retainCount = 1;
	
	// Remember: The delegateList is a linked list of MulticastDelegateListNode objects.
	// Each node object is allocated and placed in the list.
	// It is not deallocated until it is later removed from the linked list.
	
	if(delegateList != NULL)
	{
        node->prev = NULL;
		node->next = delegateList;
		node->next->prev = node;
	}
    else
    {
        node->prev = NULL;
        node->next = NULL;
    }
	
	delegateList = node;
}

- (void)removeDelegate:(id)delegate
{
	if(delegate == nil) return;
	
	MulticastDelegateListNode *node = delegateList;
	while(node != NULL)
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
            
			if(node->prev != NULL)
				node->prev->next = node->next;
			else
				delegateList = node->next;
			
			if(node->next != NULL)
				node->next->prev = node->prev;
			
			node->prev = NULL;
			node->next = NULL;
            
            node->delegate = nil;
            MulticastDelegateListNodeRelease(node);
			
			break;
		}
		else
		{
			node = node->next;
		}
	}
}

- (void)removeAllDelegates
{
	MulticastDelegateListNode *node = delegateList;
	
	while(node != NULL)
	{
		MulticastDelegateListNode *next = node->next;
		
		node->prev = NULL;
		node->next = NULL;
		
		node->delegate = nil;
        MulticastDelegateListNodeRelease(node);
		
		node = next;
	}
	
	delegateList = NULL;
}

- (NSUInteger)count
{
	NSUInteger count = 0;
	
	MulticastDelegateListNode *node;
	for(node = delegateList; node != NULL; node = node->next)
	{
		count++;
	}
	
	return count;
}

- (MulticastDelegateEnumerator *)delegateEnumerator
{
	return [[[MulticastDelegateEnumerator alloc] initWithDelegateList:delegateList] autorelease];
}

/**
 * Forwarding fast path.
 * Available in 10.5+ (Not properly declared in NSOject until 10.6)
**/
- (id)forwardingTargetForSelector:(SEL)aSelector
{
	// We can take advantage of this if we only have one delegate (a common case),
	// or simply one delegate that responds to this selector.
	
	MulticastDelegateListNode *foundNode = NULL;
	
	MulticastDelegateListNode *node = delegateList;
	while(node != NULL)
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
	for(node = delegateList; node != NULL; node = node->next)
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
	// 1. If a delegate is added during this method, it should NOT be invoked.
	// 2. If a delegate is removed during this method that has not already been invoked, it should NOT be invoked.
	
	MulticastDelegateListNode *node = delegateList;
	
	// First we loop through the linked list so we can:
	// - Get a count of the number of delegates
	// - Get a reference to the last delegate in the list
	// 
	// Recall that new delegates are added to the beginning of the linked list.
	// The last delegate in the list is the first delegate that was added, so it will be the first that's invoked.
	// We're going to be moving backwards through the linked list as we invoke the delegates.
	
	NSUInteger nodeCount = 0;
	
	if(node != NULL)
	{
		nodeCount++;
		
		while(node->next != NULL)
		{
			nodeCount++;
			node = node->next;
		}
		
		// Note: The node variable is now pointing to the last node in the list.
	}
	
	// We're now going to create an array of all the nodes.
	// This gives us a quick and easy snapshot of the current list,
	// which will allow delegates to be added/removed from the list while we're enumerating it,
	// all without bothering us, and without violating any of the rules listed above.
	// 
	// Note: We're creating an array of pointers.
	// Each pointer points to the dynamically allocated struct.
	// If we copied the struct, we might violate rule number two.
	// So we also retain each node, to prevent it from disappearing while we're enumerating the list.
	
	MulticastDelegateListNode *nodes[nodeCount];
	
	NSUInteger i;
	for(i = 0; i < nodeCount; i++)
	{
		nodes[i] = node;
		MulticastDelegateListNodeRetain(node);
		
		node = node->prev;
	}
	
	// We now have an array of all the nodes that we're going to possibly invoke.
	// Instead of using the prev/next pointers, we're going to simply enumerate this array.
	// This allows us to pass rule number one.
	// If a delegate is removed while we're enumerating, its delegate pointer will be set to nil.
	// This allows us to pass rule number two.
	
	for(i = 0; i < nodeCount; i++)
	{
		if([nodes[i]->delegate respondsToSelector:[anInvocation selector]])
		{
			[anInvocation invokeWithTarget:nodes[i]->delegate];
		}
		
		MulticastDelegateListNodeRelease(nodes[i]);
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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation MulticastDelegateEnumerator

- (id)initWithDelegateList:(MulticastDelegateListNode *)delegateList
{
	if((self = [super init]))
	{
		numDelegates = 0;
		currentDelegateIndex = 0;
		
		// Here are the rules:
		// 1. If a delegate is added during this method, it should NOT be invoked.
		// 2. If a delegate is removed during this method that has not already been invoked, it should NOT be invoked.
		
		MulticastDelegateListNode *node = delegateList;
		
		// First we loop through the linked list so we can:
		// - Get a count of the number of delegates
		// - Get a reference to the last delegate in the list
		// 
		// Recall that new delegates are added to the beginning of the linked list.
		// The last delegate in the list is the first delegate that was added, so it will be the first that's invoked.
		// We're going to be moving backwards through the linked list as we invoke the delegates.
		
		if(node != NULL)
		{
			numDelegates++;
			
			while(node->next != NULL)
			{
				numDelegates++;
				node = node->next;
			}
			
			// Note: The node variable is now pointing to the last node in the list.
		}
		
		// We're now going to create an array of all the nodes.
		// This gives us a quick and easy snapshot of the current list,
		// which will allow delegates to be added/removed from the list while we're enumerating it,
		// all without bothering us, and without violating any of the rules listed above.
		// 
		// Note: We're creating an array of pointers.
		// Each pointer points to the dynamically allocated struct.
		// If we copied the struct, we might violate rule number two.
		// So we also retain each node, to prevent it from disappearing while we're enumerating the list.
		
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
		for(i = 0; i < numDelegates; i++)
		{
			memcpy(delegates + i, &node, ptrSize);
			MulticastDelegateListNodeRetain(node);
			
			node = node->prev;
		}
	}
	return self;
}

- (id)nextDelegate
{
	if(currentDelegateIndex < numDelegates)
	{
		MulticastDelegateListNode *node = *(delegates + currentDelegateIndex);
		
		currentDelegateIndex++;
		return node->delegate;
	}
	
	return nil;
}

- (id)nextDelegateForSelector:(SEL)selector
{
	while(currentDelegateIndex < numDelegates)
	{
		MulticastDelegateListNode *node = *(delegates + currentDelegateIndex);
		
		if([node->delegate respondsToSelector:selector])
		{
			currentDelegateIndex++;
			return node->delegate;
		}
		else
		{
			currentDelegateIndex++;
		}
	}
	
	return nil;
}

- (void)dealloc
{
	NSUInteger i;
	for(i = 0; i < numDelegates; i++)
	{
		MulticastDelegateListNodeRetain(*(delegates + 1));
	}
	
	free(delegates);
	
	[super dealloc];
}

@end
