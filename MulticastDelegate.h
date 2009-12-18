#import <Foundation/Foundation.h>

@class MulticastDelegateEnumerator;

struct MulticastDelegateListNode {
	id delegate;
	struct MulticastDelegateListNode * prev;
    struct MulticastDelegateListNode * next;
    NSUInteger retainCount;
};
typedef struct MulticastDelegateListNode MulticastDelegateListNode;


@interface MulticastDelegate : NSObject
{
	MulticastDelegateListNode *delegateList;
}

- (void)addDelegate:(id)delegate;
- (void)removeDelegate:(id)delegate;

- (void)removeAllDelegates;

- (NSUInteger)count;

- (MulticastDelegateEnumerator *)delegateEnumerator;

@end

@interface MulticastDelegateEnumerator : NSObject
{
	NSUInteger numDelegates;
	NSUInteger currentDelegateIndex;
	MulticastDelegateListNode **delegates;
}

- (id)nextDelegate;
- (id)nextDelegateForSelector:(SEL)selector;

@end
