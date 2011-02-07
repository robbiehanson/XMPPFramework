#import "DDList.h"


@interface DDListEnumerator (PrivateAPI)

- (id)initWithList:(DDListNode *)list reverse:(BOOL)reverse;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation DDList

- (id)init
{
	if ((self = [super init]))
	{
		list = NULL;
	}
	return self;
}

- (void)add:(void *)element
{
	if(element == NULL) return;
	
	DDListNode *node = malloc(sizeof(DDListNode));
	
    node->element = element;
	
	// Remember: The list is a linked list of DDListNode objects.
	// Each node object is allocated and placed in the list.
	// It is not deallocated until it is later removed from the linked list.
	
	if (list == NULL)
	{
		node->prev = NULL;
        node->next = NULL;
	}
    else
    {
        node->prev = NULL;
		node->next = list;
		node->next->prev = node;
    }
	
	list = node;
}

- (void)remove:(void *)element allInstances:(BOOL)allInstances
{
	if(element == NULL) return;
	
	DDListNode *node = list;
	while (node != NULL)
	{
		if (element == node->element)
		{
			// Remove the node from the list.
			// This is done by editing the pointers of the node's neighbors to skip it.
			// 
			// In other words:
			// node->prev->next = node->next
			// node->next->prev = node->prev
			// 
			// We also want to properly update our list pointer,
			// which always points to the "first" element in the list. (Most recently added.)
            
			if (node->prev != NULL)
				node->prev->next = node->next;
			else
				list = node->next;
			
			if (node->next != NULL)
				node->next->prev = node->prev;
			
			free(node);
			
			if (!allInstances) break;
		}
		else
		{
			node = node->next;
		}
	}
}

- (void)remove:(void *)element
{
	[self remove:element allInstances:NO];
}

- (void)removeAll:(void *)element
{
	[self remove:element allInstances:YES];
}

- (void)removeAllElements
{
	DDListNode *node = list;
	while (node != NULL)
	{
		DDListNode *next = node->next;
		
		free(node);
		node = next;
	}
	
	list = NULL;
}

- (NSUInteger)count
{
	NSUInteger count = 0;
	
	DDListNode *node;
	for (node = list; node != NULL; node = node->next)
	{
		count++;
	}
	
	return count;
}

- (DDListEnumerator *)listEnumerator
{
	return [[[DDListEnumerator alloc] initWithList:list reverse:NO] autorelease];
}

- (DDListEnumerator *)reverseListEnumerator
{
	return [[[DDListEnumerator alloc] initWithList:list reverse:YES] autorelease];
}

- (void)dealloc
{
	[self removeAllElements];
	[super dealloc];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation DDListEnumerator

- (id)initWithList:(DDListNode *)aList reverse:(BOOL)reverse
{
	if ((self = [super init]))
	{
		numElements = 0;
		currentElementIndex = 0;
		
		// First get a count of the number of elements in the given list.
		// Also, get a reference to the last node in the list.
		
		DDListNode *node = aList;
		
		if (node != NULL)
		{
			numElements++;
			
			while (node->next != NULL)
			{
				numElements++;
				node = node->next;
			}
		}
		
		// At this point:
		// 
		// aList -> points to the first element in the list
		// node  -> points to the last element in the list
		
		// Recall that new elements are added to the beginning of the linked list.
		// The last element in the list is the first element that was added.
		
		if (numElements > 0)
		{
			elements = malloc(numElements * sizeof(void *));
			
			if (reverse)
			{
				NSUInteger i = 0;
				
				while (aList != NULL)
				{
					elements[i] = aList->element;
					
					i++;
					aList = aList->next;
				}			
			}
			else
			{
				NSUInteger i = 0;
				
				while (node != NULL)
				{
					elements[i] = node->element;
					
					i++;
					node = node->prev;
				}
			}
		}
	}
	return self;
}

- (NSUInteger)numTotal
{
	return numElements;
}

- (NSUInteger)numLeft
{
	if (currentElementIndex < numElements)
		return numElements - currentElementIndex;
	else
		return 0;
}

- (void *)nextElement
{
	if (currentElementIndex < numElements)
	{
		void *element = elements[currentElementIndex];
		currentElementIndex++;
		
		return element;
	}
	else
	{
		return NULL;
	}
}

- (void)dealloc
{
	if (elements)
	{
		free(elements);
	}
	[super dealloc];
}

@end
