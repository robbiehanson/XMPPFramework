#import <Foundation/Foundation.h>

@class GCDMulticastDelegateEnumerator;

/**
 * This class provides multicast delegate functionality. That is:
 * - it provides a means for managing a list of delegates
 * - any method invocations to an instance of this class are automatically forwarded to all delegates
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
 * as multiple delegates can usually be handled in a manner similar to the traditional single delegate paradigm.
 * 
 * This class also provides proper support for GCD queues.
 * So each delegate specifies which queue they would like their delegate invocations to be dispatched onto.
 * 
 * All delegate dispatching is done asynchronously (which is a critically important architectural design).
**/

NS_ASSUME_NONNULL_BEGIN
@interface GCDMulticastDelegate : NSObject

- (void)addDelegate:(id)delegate delegateQueue:(dispatch_queue_t)delegateQueue;
- (void)removeDelegate:(id)delegate delegateQueue:(nullable dispatch_queue_t)delegateQueue;
- (void)removeDelegate:(id)delegate;

- (void)removeAllDelegates;

@property (nonatomic, readonly) NSUInteger count;
- (NSUInteger)countOfClass:(Class)aClass;
- (NSUInteger)countForSelector:(SEL)aSelector;

- (BOOL)hasDelegateThatRespondsToSelector:(SEL)aSelector;

- (GCDMulticastDelegateEnumerator *)delegateEnumerator;

@end


@interface GCDMulticastDelegateEnumerator : NSObject

@property (nonatomic, readonly) NSUInteger count;
- (NSUInteger)countOfClass:(Class)aClass;
- (NSUInteger)countForSelector:(SEL)aSelector;

- (BOOL)getNextDelegate:(id _Nullable * _Nonnull)delPtr delegateQueue:(dispatch_queue_t _Nullable * _Nonnull)dqPtr;
- (BOOL)getNextDelegate:(id _Nullable * _Nonnull)delPtr delegateQueue:(dispatch_queue_t _Nullable * _Nonnull)dqPtr ofClass:(Class)aClass;
- (BOOL)getNextDelegate:(id _Nullable * _Nonnull)delPtr delegateQueue:(dispatch_queue_t _Nullable * _Nonnull)dqPtr forSelector:(SEL)aSelector;

@end
NS_ASSUME_NONNULL_END
