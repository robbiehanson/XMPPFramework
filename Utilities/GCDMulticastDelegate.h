#import <Foundation/Foundation.h>

@class GCDMulticastDelegateEnumerator;

struct GCDMulticastDelegateListNode {
	id delegate;
	dispatch_queue_t delegateQueue;
	struct GCDMulticastDelegateListNode * prev;
    struct GCDMulticastDelegateListNode * next;
    int32_t retainCount;
};
typedef struct GCDMulticastDelegateListNode GCDMulticastDelegateListNode;

/**
 * This class provides multicast delegate functionality.
 * That is, it provides a means for managing a list of delegates,
 * and any method invocations to an instance of the class are automatically forwarded to all delegates.
 * 
 * For example:
 * 
 * // Make this method call on every added delegate (there may be several)
 * [multicastDelegate cog:self didFindThing:thing];
 * 
 * This allows multiple delegates to be added to an xmpp stream or any xmpp module,
 * which in turn makes development easier as there can be proper separation of logically different code sections.
 * 
 * In addition, this makes module development easier,
 * as multiple delegates can be handled in the same manner as the traditional single delegate paradigm.
 * 
 * This class also provides proper support for GCD queues.
 * So each delegate specifies which queue they would like their delegate invocations to be dispatched onto.
 * 
 * All delegate dispatching is done asynchronously (which is a critically important architectural design).
**/

@interface GCDMulticastDelegate : NSObject
{
	GCDMulticastDelegateListNode *delegateList;
}

- (void)addDelegate:(id)delegate delegateQueue:(dispatch_queue_t)delegateQueue;
- (void)removeDelegate:(id)delegate delegateQueue:(dispatch_queue_t)delegateQueue;
- (void)removeDelegate:(id)delegate;

- (void)removeAllDelegates;

- (NSUInteger)count;
- (NSUInteger)countOfClass:(Class)aClass;
- (NSUInteger)countForSelector:(SEL)aSelector;

- (GCDMulticastDelegateEnumerator *)delegateEnumerator;

@end

@interface GCDMulticastDelegateEnumerator : NSObject
{
	NSUInteger numDelegates;
	NSUInteger currentDelegateIndex;
	GCDMulticastDelegateListNode **delegates;
}

- (NSUInteger)count;
- (NSUInteger)countOfClass:(Class)aClass;
- (NSUInteger)countForSelector:(SEL)aSelector;

- (BOOL)getNextDelegate:(id *)delPtr delegateQueue:(dispatch_queue_t *)dqPtr;
- (BOOL)getNextDelegate:(id *)delPtr delegateQueue:(dispatch_queue_t *)dqPtr ofClass:(Class)aClass;
- (BOOL)getNextDelegate:(id *)delPtr delegateQueue:(dispatch_queue_t *)dqPtr forSelector:(SEL)aSelector;

@end
