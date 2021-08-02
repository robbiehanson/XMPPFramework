#import <Foundation/Foundation.h>
#import "GCDMulticastDelegate.h"

@class XMPPStream;

/**
 * XMPPModule is the base class that all extensions/modules inherit.
 * They automatically get:
 * 
 * - A dispatch queue.
 * - A multicast delegate that automatically invokes added delegates.
 * 
 * The module also automatically registers/unregisters itself with the
 * xmpp stream during the activate/deactive methods.
**/
NS_ASSUME_NONNULL_BEGIN
@interface XMPPModule : NSObject
{
	XMPPStream *xmppStream;

	dispatch_queue_t moduleQueue;
	void *moduleQueueTag;
	
	id multicastDelegate;
}

@property (readonly) dispatch_queue_t moduleQueue;
@property (readonly) void *moduleQueueTag;
@property (strong, readonly, nullable) XMPPStream *xmppStream;
@property (nonatomic, readonly) NSString *moduleName;
@property (nonatomic, readonly) id multicastDelegate NS_REFINED_FOR_SWIFT;

- (instancetype)init;
- (instancetype)initWithDispatchQueue:(nullable dispatch_queue_t)queue;

- (BOOL)activate:(XMPPStream *)aXmppStream;
- (void)deactivate;

- (void)addDelegate:(id)delegate delegateQueue:(dispatch_queue_t)delegateQueue;
- (void)removeDelegate:(id)delegate delegateQueue:(dispatch_queue_t)delegateQueue;
- (void)removeDelegate:(id)delegate;

@end

/**
 * These helper methods are useful when synchronizing
 * external access to properties in XMPPModule subclasses.
 */
@interface XMPPModule(Synchronization)
/**
 * Dispatches block synchronously on moduleQueue, or
 * executes directly if we're already on the moduleQueue.
 * This is most useful for synchronizing external read
 * access to properties when writing XMPPModule subclasses.
 *
 *  if (dispatch_get_specific(moduleQueueTag))
 *      block();
 *  else
 *      dispatch_sync(moduleQueue, block);
 */
- (void) performBlock:(dispatch_block_t)block NS_REFINED_FOR_SWIFT;

/**
 * Dispatches block asynchronously on moduleQueue, or
 * executes directly if we're already on the moduleQueue.
 * This is most useful for synchronizing external write
 * access to properties when writing XMPPModule subclasses.
 *
 *  if (dispatch_get_specific(moduleQueueTag))
 *      block();
 *  else
 *      dispatch_async(moduleQueue, block);
 */
- (void) performBlockAsync:(dispatch_block_t)block NS_REFINED_FOR_SWIFT;
@end
NS_ASSUME_NONNULL_END
