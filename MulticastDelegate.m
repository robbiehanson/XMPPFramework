#import "MulticastDelegate.h"

@interface MulticastDelegateListNode (PrivateAPI)
- (void)clearDelegate;
@end

@implementation MulticastDelegate

- (id)init
{
	if(self = [super init])
	{
		currentInvocationIndex = 0;
	}
	return self;
}

- (void)addDelegate:(id)delegate
{
	MulticastDelegateListNode *node = [[MulticastDelegateListNode alloc] initWithDelegate:delegate];
	
	if(delegateList != nil)
	{
		[node setNext:delegateList];
		[[node next] setPrev:node];
	}
	
	delegateList = node;
}

- (void)removeDelegate:(id)delegate
{
	MulticastDelegateListNode *node = delegateList;
	NSUInteger index = 0;
	
	while(node != nil)
	{
		if(delegate == [node delegate])
		{
			if([node prev] == nil)
				delegateList = [node next];
			else
				[[node prev] setNext:[node next]];
			
			[[node next] setPrev:[node prev]];
			
			// We do NOT change the prev/next pointers of the node.
			// If it's in use within forwardInvocation, these pointers are still needed.
			// However, if multiple delegates are removed in the middle of a delegate callback,
			// we still need to be sure not to invoke any delegates that were removed.
			[node clearDelegate];
			[node release];
			
			if(index < currentInvocationIndex)
			{
				currentInvocationIndex--;
			}
			break;
		}
		
		index++;
		node = [node next];
	}
}

- (void)removeAllDelegates
{
	MulticastDelegateListNode *node = delegateList;
	
	while(node != nil)
	{
		MulticastDelegateListNode *next = [node next];
		
		[node setPrev:nil];
		[node setNext:nil];
		[node release];
		
		node = next;
	}
	
	currentInvocationIndex = 0;
	delegateList = nil;
}

- (NSUInteger)count
{
	NSUInteger count = 0;
	
	MulticastDelegateListNode *node;
	for(node = delegateList; node != nil; node = [node next])
	{
		count++;
	}
	
	return count;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
	MulticastDelegateListNode *node;
	for(node = delegateList; node != nil; node = [node next])
	{
		NSMethodSignature *result = [[node delegate] methodSignatureForSelector:aSelector];
		
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
	// If a delegate is removed during this method that has not already been invoked, it should not be invoked.
	// 
	// The first rule is the reason for the currentInvocationIndex variable.
	
	MulticastDelegateListNode *node = delegateList;
	currentInvocationIndex = 0;
	
	while([node next] != nil)
	{
		node = [node next];
		currentInvocationIndex++;
	}
	
	while(node != nil)
	{
		// Retain the node before we invoke the delegate.
		// We do this because the delegate might remove itself from the delegate list within the invoked method.
		// And we don't want to get the previous node now, because it may also be
		// removed from the list within the invoked method.
		[[node retain] autorelease];
		
		if([[node delegate] respondsToSelector:[anInvocation selector]])
		{
			[anInvocation invokeWithTarget:[node delegate]];
		}
		
		node = [node prev];
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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation MulticastDelegateListNode

- (id)initWithDelegate:(id)aDelegate
{
	if(self = [super init])
	{
		delegate = aDelegate;
	}
	return self;
}

- (void)dealloc
{
	[super dealloc];
}

- (id)delegate
{
	return delegate;
}

- (void)clearDelegate
{
	delegate = nil;
}

- (MulticastDelegateListNode *)prev
{
	return prev;
}

- (void)setPrev:(MulticastDelegateListNode *)newPrev
{
	prev = newPrev;
}

- (MulticastDelegateListNode *)next
{
	return next;
}

- (void)setNext:(MulticastDelegateListNode *)newNext
{
	next = newNext;
}

@end