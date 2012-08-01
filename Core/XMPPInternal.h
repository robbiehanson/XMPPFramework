//
//  This file is for XMPPStream and various internal components.
//

#import "XMPPStream.h"
#import "XMPPModule.h"

// Define the various states we'll use to track our progress
enum XMPPStreamState
{
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
typedef enum XMPPStreamState XMPPStreamState;

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

@interface XMPPStream (/* Internal */)

/**
 * Categories on XMPPStream should maintain thread safety by dispatching through the internal xmppQueue.
 * They may also need to ensure the stream is in the proper state for their activity.
**/

@property (readonly) dispatch_queue_t xmppQueue;
@property (readonly) XMPPStreamState state;

/**
 * This method is for use by xmpp authentication mechanism classes.
 * They should send elements using this method instead of the public sendElement classes,
 * as those methods don't send the elements while authentication is in progress.
**/
- (void)sendAuthElement:(NSXMLElement *)element;

/**
 * This method allows you to inject an element into the stream as if it was received on the socket.
 * This is an advanced technique, but makes for some interesting possibilities.
**/
- (void)injectElement:(NSXMLElement *)element;

@end

@interface XMPPModule (/* Internal */)

/**
 * Used internally by methods like XMPPStream's unregisterModule:.
 * Normally removing a delegate is a synchronous operation, but due to multiple dispatch_sync operations,
 * it must occasionally be done asynchronously to avoid deadlock.
**/
- (void)removeDelegate:(id)delegate delegateQueue:(dispatch_queue_t)delegateQueue synchronously:(BOOL)synchronously;

@end
