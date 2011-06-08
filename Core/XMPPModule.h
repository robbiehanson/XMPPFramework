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
@interface XMPPModule : NSObject
{
	XMPPStream *xmppStream;
	
	dispatch_queue_t moduleQueue;
	id multicastDelegate;
}

@property (readonly) dispatch_queue_t moduleQueue;
@property (readonly) XMPPStream *xmppStream;

- (id)init;
- (id)initWithDispatchQueue:(dispatch_queue_t)queue;

- (BOOL)activate:(XMPPStream *)xmppStream;
- (void)deactivate;

- (void)addDelegate:(id)delegate delegateQueue:(dispatch_queue_t)delegateQueue;
- (void)removeDelegate:(id)delegate delegateQueue:(dispatch_queue_t)delegateQueue;
- (void)removeDelegate:(id)delegate;

- (NSString *)moduleName;

@end
