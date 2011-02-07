#import "DelegateList.h"

/**
 * 
**/

@interface DelegateListEnumerator (PrivateAPI)

- (id)initWithDelegateList:(DelegateListNode *)delegateList;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

static void DelegateListNodeRetain(DelegateListNode *node)
{
	node->retainCount++;
}

static void DelegateListNodeRelease(DelegateListNode *node)
{
	node->retainCount--;
	
	if (node->retainCount == 0)
	{
		free(node);
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation DelegateList

- (id)init
{
	if ((self = [super init]))
	{
		delegateList = NULL;
	}
	return self;
}

- (void)addDelegate:(id)delegate
{
	if(delegate == nil) return;
	
	DelegateListNode *node = malloc(sizeof(DelegateListNode));
	
    node->delegate = delegate;
    node->retainCount = 1;
	
	// Remember: The delegateList is a linked list of DelegateListNode objects.
	// Each node object is allocated and placed in the list.
	// It is not deallocated until it is later removed from the linked list.
	
	if (delegateList != NULL)
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
	
	DelegateListNode *node = delegateList;
	while (node != NULL)
	{
		if (delegate == node->delegate)
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
            
			if (node->prev != NULL)
				node->prev->next = node->next;
			else
				delegateList = node->next;
			
			if (node->next != NULL)
				node->next->prev = node->prev;
			
			node->prev = NULL;
			node->next = NULL;
            
            node->delegate = nil;
            DelegateListNodeRelease(node);
			
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
	DelegateListNode *node = delegateList;
	
	while (node != NULL)
	{
		DelegateListNode *next = node->next;
		
		node->prev = NULL;
		node->next = NULL;
		
		node->delegate = nil;
        DelegateListNodeRelease(node);
		
		node = next;
	}
	
	delegateList = NULL;
}

- (NSUInteger)count
{
	NSUInteger count = 0;
	
	DelegateListNode *node;
	for (node = delegateList; node != NULL; node = node->next)
	{
		count++;
	}
	
	return count;
}

- (DelegateListEnumerator *)delegateEnumerator
{
	return [[[DelegateListEnumerator alloc] initWithDelegateList:delegateList] autorelease];
}

- (void)dealloc
{
	[self removeAllDelegates];
	[super dealloc];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation DelegateListEnumerator

- (id)initWithDelegateList:(DelegateListNode *)delegateList
{
	if ((self = [super init]))
	{
		numDelegates = 0;
		currentDelegateIndex = 0;
		
		// Here are the rules:
		// 1. If a delegate is added during this method, it should NOT be invoked.
		// 2. If a delegate is removed during this method that has not already been invoked, it should NOT be invoked.
		
		DelegateListNode *node = delegateList;
		
		// First we loop through the linked list so we can:
		// - Get a count of the number of delegates
		// - Get a reference to the last delegate in the list
		// 
		// Recall that new delegates are added to the beginning of the linked list.
		// The last delegate in the list is the first delegate that was added, so it will be the first that's invoked.
		// We're going to be moving backwards through the linked list as we invoke the delegates.
		
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
		for (i = 0; i < numDelegates; i++)
		{
			memcpy(delegates + i, &node, ptrSize);
			DelegateListNodeRetain(node);
			
			node = node->prev;
		}
	}
	return self;
}

- (NSUInteger)count
{
	return numDelegates;
}

- (id)nextDelegate
{
	while (currentDelegateIndex < numDelegates)
	{
		DelegateListNode *node = *(delegates + currentDelegateIndex);
		currentDelegateIndex++;
		
		if (node->delegate)
		{
			return node->delegate;
		}
	}
	
	return nil;
}

- (id)nextDelegateOfClass:(Class)aClass
{
	while (currentDelegateIndex < numDelegates)
	{
		DelegateListNode *node = *(delegates + currentDelegateIndex);
		currentDelegateIndex++;
		
		if ([node->delegate isKindOfClass:aClass])
		{
			return node->delegate;
		}
	}
	
	return nil;
}

- (id)nextDelegateForSelector:(SEL)aSelector
{
	while (currentDelegateIndex < numDelegates)
	{
		DelegateListNode *node = *(delegates + currentDelegateIndex);
		currentDelegateIndex++;
		
		if([node->delegate respondsToSelector:aSelector])
		{
			return node->delegate;
		}
	}
	
	return nil;
}

- (void)dealloc
{
	NSUInteger i;
	for (i = 0; i < numDelegates; i++)
	{
		DelegateListNode *node = *(delegates + i);
		DelegateListNodeRelease(node);
	}
	
	free(delegates);
	
	[super dealloc];
}

@end