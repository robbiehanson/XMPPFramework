#import <Foundation/Foundation.h>
@class MulticastDelegateListNode;


@interface MulticastDelegate : NSObject
{
	NSUInteger currentInvocationIndex;
	MulticastDelegateListNode *delegateList;
}

- (void)addDelegate:(id)delegate;
- (void)removeDelegate:(id)delegate;

- (void)removeAllDelegates;

- (NSUInteger)count;

@end

@interface MulticastDelegateListNode : NSObject
{
	id delegate;
	
	MulticastDelegateListNode *prev;
	MulticastDelegateListNode *next;
}

- (id)initWithDelegate:(id)delegate;

- (id)delegate;

- (MulticastDelegateListNode *)prev;
- (void)setPrev:(MulticastDelegateListNode *)prev;

- (MulticastDelegateListNode *)next;
- (void)setNext:(MulticastDelegateListNode *)next;

@end