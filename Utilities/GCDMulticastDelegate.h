#import <Foundation/Foundation.h>

@class GCDMulticastDelegateEnumerator, GCDMulticastDelegateInvocationContext;

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

/**
 * A helper class for propagating custom context across multicast delegate invocations.
 *
 * This class serves 2 main purposes:
 * - provides an auxiliary path of custom data delivery to the invoked delegate methods
 * - makes it possible to track the delegate method invocation completion
 *
 * The context propagates along the cascade of invocations, i.e. when a delegate method calls another multicast delegate,
 * that subsequent invocation belongs to the same context. This is particularly relevant w.r.t. the xmpp framework
 * architecture where a scenario with two layers of delegation is common: stream -> module and module -> application.
 * The propagating context is what enables the framework to deliver stream event-related information across modules
 * to the application callbacks.
 *
 * The default context propagation junctions are invocation forwarding and delegate enumerator creation. As long as
 * they are executed under an existing context, the propagation is automatic.
 *
 * A manual propagation scenario (e.g. asynchronous message processing within a module) would consist of the following steps:
 * 1. Capturing the context object while still in the delegate callback context with @c currentContext.
 * 2. Entering the captured context's @c continuityGroup.
 * 3. Restoring the context on an arbitrary queue with @c becomeCurrentOnQueue:forActionWithBlock:
 * 4. Leaving the @c continuityGroup within the action block submitted to @c becomeCurrentOnQueue:forActionWithBlock:
 *
 * Steps 2. and 4. are only required if @c becomeCurrentOnQueue:forActionWithBlock: itself is invoked asynchronously
 * (e.g. in a network or disk IO completion callback).
 */
@interface GCDMulticastDelegateInvocationContext : NSObject

@property (nonatomic, strong, readonly) id value;
@property (nonatomic, strong, readonly) dispatch_group_t continuityGroup;

+ (instancetype)currentContext;

- (instancetype)initWithValue:(id)value;
- (instancetype)init NS_UNAVAILABLE;

- (void)becomeCurrentOnQueue:(dispatch_queue_t)queue forActionWithBlock:(dispatch_block_t)block;

@end
NS_ASSUME_NONNULL_END
