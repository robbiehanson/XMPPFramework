#import "DDList.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif


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
		listHead = NULL;
		listTail = NULL;
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
	
	if (listTail == NULL)
	{
		node->next = NULL;
		node->prev = NULL;
	}
    else
    {
		node->next = NULL;
        node->prev = listTail;
		node->prev->next = node;
    }
	
	listTail = node;
	
	if (listHead == NULL)
		listHead = node;
}

- (void)remove:(void *)element allInstances:(BOOL)allInstances
{
	if(element == NULL) return;
	
	DDListNode *node = listHead;
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
				listHead = node->next;
			
			if (node->next != NULL)
				node->next->prev = node->prev;
			else
				listTail = node->prev;
			
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
	DDListNode *node = listHead;
	while (node != NULL)
	{
		DDListNode *next = node->next;
		
		free(node);
		node = next;
	}
	
	listHead = NULL;
	listTail = NULL;
}

- (BOOL)contains:(void *)element
{
	DDListNode *node;
	for (node = listHead; node != NULL; node = node->next)
	{
		if (node->element == element)
		{
			return YES;
		}
	}
	
	return NO;
}

- (NSUInteger)count
{
	NSUInteger count = 0;
	
	DDListNode *node;
	for (node = listHead; node != NULL; node = node->next)
	{
		count++;
	}
	
	return count;
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
                                  objects:(id __unsafe_unretained [])buffer
                                    count:(NSUInteger)len
{
	DDListNode *currentNode;
	
	if (state->extra[0] == 1)
		return 0;
	
	if (state->state == 0)
		currentNode = listHead;
	else
		currentNode = (DDListNode *)state->state;
	
	NSUInteger batchCount = 0;
	while (currentNode != NULL && batchCount < len)
	{
		buffer[batchCount] = (__bridge id)currentNode->element;
		currentNode = currentNode->next;
		batchCount++;
	}
	
	state->state = (unsigned long)currentNode;
	state->itemsPtr = buffer;
	state->mutationsPtr = (__bridge void *)self;
	
	if (currentNode == NULL)
		state->extra[0] = 1;
	else
		state->extra[0] = 0;
	
	return batchCount;
}

- (DDListEnumerator *)listEnumerator
{
	return [[DDListEnumerator alloc] initWithList:listHead reverse:NO];
}

- (DDListEnumerator *)reverseListEnumerator
{
	return [[DDListEnumerator alloc] initWithList:listTail reverse:YES];
}

- (void)dealloc
{
	[self removeAllElements];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation DDListEnumerator

- (id)initWithList:(DDListNode *)list reverse:(BOOL)reverse
{
	if ((self = [super init]))
	{
		numElements = 0;
		currentElementIndex = 0;
		
		// First get a count of the number of elements in the given list.
		
		if (reverse)
		{
			for (DDListNode *node = list; node != NULL; node = node->prev)
			{
				numElements++;
			}
		}
		else
		{
			for (DDListNode *node = list; node != NULL; node = node->next)
			{
				numElements++;
			}
			
		}
		
		// Now copy the list into a C array.
		
		if (numElements > 0)
		{
			elements = malloc(numElements * sizeof(void *));
			
			DDListNode *node = list;
			
			if (reverse)
			{
				for (NSUInteger i = 0; i < numElements; i++)
				{
					elements[i] = node->element;
					node = node->prev;
				}			
			}
			else
			{
				for (NSUInteger i = 0; i < numElements; i++)
				{
					elements[i] = node->element;
					node = node->next;
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
}

@end
