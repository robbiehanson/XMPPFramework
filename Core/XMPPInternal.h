//
//  This file is for XMPPStream and various internal components.
//

#import "XMPPStream.h"
#import "XMPPModule.h"
#import "XMPPParser.h"

// Define the various states we'll use to track our progress
typedef NS_ENUM(NSInteger, XMPPStreamState) {
	STATE_XMPP_DISCONNECTED,
	STATE_XMPP_RESOLVING_SRV,
	STATE_XMPP_CONNECTING,
	STATE_XMPP_OPENING,
	STATE_XMPP_NEGOTIATING,
	STATE_XMPP_STARTTLS_1,
	STATE_XMPP_STARTTLS_2,
	STATE_XMPP_POST_NEGOTIATION,
	STATE_XMPP_REGISTERING,
	STATE_XMPP_AUTH,
	STATE_XMPP_BINDING,
	STATE_XMPP_START_SESSION,
	STATE_XMPP_CONNECTED,
};

NS_ASSUME_NONNULL_BEGIN

/**
 * It is recommended that storage classes cache a stream's myJID.
 * This prevents them from constantly querying the property from the xmppStream instance,
 * as doing so goes through xmppStream's dispatch queue.
 * Caching the stream's myJID frees the dispatch queue to handle xmpp processing tasks.
 * 
 * The object of the notification will be the XMPPStream instance.
 * 
 * Note: We're not using the typical MulticastDelegate paradigm for this task as
 * storage classes are not typically added as a delegate of the xmppStream. 
**/
extern NSString *const XMPPStreamDidChangeMyJIDNotification;

@interface XMPPStream (/* Internal */) <XMPPParserDelegate>

/**
 * XMPPStream maintains thread safety by dispatching  through the internal serial xmppQueue.
 * Subclasses of XMPPStream MUST follow the same technique:
 * 
 * dispatch_block_t block = ^{
 *     // Code goes here
 * };
 * 
 * if (dispatch_get_specific(xmppQueueTag))
 *   block();
 * else
 *   dispatch_sync(xmppQueue, block);
 *
 * Category methods may or may not need to dispatch through the xmppQueue.
 * It depends entirely on what properties of xmppStream the category method needs to access.
 * For example, if a category only accesses a single property, such as the rootElement,
 * then it can simply fetch the atomic property, inspect it, and complete its job.
 * However, if the category needs to fetch multiple properties, then it likely needs to fetch all such
 * properties in an atomic fashion. In this case, the category should likely go through the xmppQueue,
 * to ensure that it gets an atomic state of the xmppStream in order to complete its job.
**/
@property (nonatomic, readonly) dispatch_queue_t xmppQueue;
@property (nonatomic, readonly) void *xmppQueueTag;

/** 
 * Returns the underlying socket for the stream.
 * You shouldn't mess with this unless you really
 * know what you're doing.
 */
@property (nonatomic, readonly) GCDAsyncSocket *asyncSocket;

/**
 * Returns the current state of the xmppStream.
**/
@property (atomic, readonly) XMPPStreamState state;

/**
 * This method is for use by xmpp authentication mechanism classes.
 * They should send elements using this method instead of the public sendElement methods,
 * as those methods don't send the elements while authentication is in progress.
 * 
 * @see XMPPSASLAuthentication
**/
- (void)sendAuthElement:(NSXMLElement *)element;

/**
 * This method is for use by xmpp custom binding classes.
 * They should send elements using this method instead of the public sendElement methods,
 * as those methods don't send the elements while authentication/binding is in progress.
 * 
 * @see XMPPCustomBinding
**/
- (void)sendBindElement:(NSXMLElement *)element;

/**
 * This method allows you to inject an element into the stream as if it was received on the socket.
 * This is an advanced technique, but makes for some interesting possibilities.
**/
- (void)injectElement:(NSXMLElement *)element;

/**
 * The XMPP standard only supports <iq>, <message> and <presence> stanzas (excluding session setup stuff).
 * But some extensions use non-standard element types.
 * The standard example is XEP-0198, which uses <r> & <a> elements.
 * 
 * XMPPStream will assume that any non-standard element types are errors, unless you register them.
 * Once registered the stream can recognize them, and will use the following delegate methods:
 * 
 * xmppStream:didSendCustomElement:
 * xmppStream:didReceiveCustomElement:
**/
- (void)registerCustomElementNames:(NSSet<NSString*> *)names;
- (void)unregisterCustomElementNames:(NSSet<NSString*> *)names;

@end

@interface XMPPModule (/* Internal */)

/**
 * Used internally by methods like XMPPStream's unregisterModule:.
 * Normally removing a delegate is a synchronous operation, but due to multiple dispatch_sync operations,
 * it must occasionally be done asynchronously to avoid deadlock.
**/
- (void)removeDelegate:(id)delegate
         delegateQueue:(dispatch_queue_t)delegateQueue
         synchronously:(BOOL)synchronously;

@end

NS_ASSUME_NONNULL_END
