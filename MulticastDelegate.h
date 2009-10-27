#import <Foundation/Foundation.h>

struct MulticastDelegateListNode {
	id delegate;
	struct MulticastDelegateListNode * prev;
    struct MulticastDelegateListNode * next;
    NSUInteger retainCount;
};
typedef struct MulticastDelegateListNode MulticastDelegateListNode;


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
