#import <Foundation/Foundation.h>

@class DelegateListEnumerator;

struct DelegateListNode {
	id delegate;
	struct DelegateListNode * prev;
    struct DelegateListNode * next;
    NSUInteger retainCount;
};
typedef struct DelegateListNode DelegateListNode;


@interface DelegateList : NSObject
{
	DelegateListNode *delegateList;
}

- (void)addDelegate:(id)delegate;
- (void)removeDelegate:(id)delegate;

- (void)removeAllDelegates;

- (NSUInteger)count;

- (DelegateListEnumerator *)delegateEnumerator;

@end

@interface DelegateListEnumerator : NSObject
{
	NSUInteger numDelegates;
	NSUInteger currentDelegateIndex;
	DelegateListNode **delegates;
}

- (NSUInteger)count;

- (id)nextDelegate;
- (id)nextDelegateOfClass:(Class)aClass;
- (id)nextDelegateForSelector:(SEL)aSelector;

@end
