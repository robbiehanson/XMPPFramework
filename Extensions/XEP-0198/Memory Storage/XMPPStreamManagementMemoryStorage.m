#import "XMPPStreamManagementMemoryStorage.h"
#import <libkern/OSAtomic.h>


@interface XMPPStreamManagementMemoryStorage ()

@property (atomic, weak, readwrite) XMPPStreamManagement *parent;
@end

#pragma mark -

@implementation XMPPStreamManagementMemoryStorage
{
	int32_t isConfigured;
	
	NSString *resumptionId;
	uint32_t timeout;
	
	NSDate *lastDisconnect;
	uint32_t lastHandledByClient;
	uint32_t lastHandledByServer;
	NSArray *pendingOutgoingStanzas;
	
}

- (BOOL)configureWithParent:(XMPPStreamManagement *)parent queue:(dispatch_queue_t)queue
{
	// This implementation only supports a single xmppStream.
	// You must create multiple instances for multiple xmppStreams.
	
	return OSAtomicCompareAndSwap32(0, 1, &isConfigured);
}

/**
 * Invoked after we receive <enabled/> from the server.
 * 
 * @param resumptionId
 *   The ID required to resume the session, given to us by the server.
 *   
 * @param timeout
 *   The timeout in seconds.
 *   After a disconnect, the server will maintain our state for this long.
 *   If we attempt to resume the session after this timeout it likely won't work.
 * 
 * @param lastDisconnect
 *   Used to reset the lastDisconnect value.
 *   This value is often updated during the session, to ensure it closely resemble the date the server will use.
 *   That is, if the client application is killed (or crashes) we want a relatively accurate lastDisconnect date.
 * 
 * @param stream
 *   The associated xmppStream (standard parameter for storage classes)
 * 
 * This method should also nil out the following values (if needed) associated with the account:
 * - lastHandledByClient
 * - lastHandledByServer
 * - pendingOutgoingStanzas
**/
- (void)setResumptionId:(NSString *)inResumptionId
                timeout:(uint32_t)inTimeout
         lastDisconnect:(NSDate *)inLastDisconnect
              forStream:(XMPPStream *)stream
{
	resumptionId = inResumptionId;
	timeout = inTimeout;
	lastDisconnect = inLastDisconnect;
	
	lastHandledByClient = 0;
	lastHandledByServer = 0;
	pendingOutgoingStanzas = nil;
}

/**
 * This method is invoked ** often ** during stream operation.
 * It is not invoked when the xmppStream is disconnected.
 *
 * Important: See the note [in XMPPStreamManagement.h]: "Optimizing storage demands during active stream usage"
 * 
 * @param date
 *   Updates the previous lastDisconnect value.
 *
 * @param lastHandledByClient
 *   The most recent 'h' value we can safely send to the server.
 * 
 * @param stream
 *   The associated xmppStream (standard parameter for storage classes)
**/
- (void)setLastDisconnect:(NSDate *)inLastDisconnect
      lastHandledByClient:(uint32_t)inLastHandledByClient
                forStream:(XMPPStream *)stream
{
	lastDisconnect = inLastDisconnect;
	lastHandledByClient = inLastHandledByClient;
}

/**
 * This method is invoked ** often ** during stream operation.
 * It is not invoked when the xmppStream is disconnected.
 * 
 * Important: See the note [in XMPPStreamManagement.h]: "Optimizing storage demands during active stream usage"
 *
 * @param date
 *   Updates the previous lastDisconnect value.
 *
 * @param lastHandledByServer
 *   The most recent 'h' value we've received from the server.
 *
 * @param pendingOutgoingStanzas
 *   An array of XMPPStreamManagementOutgoingStanza objects.
 *   The storage layer is in charge of properly persisting this array, including:
 *   - the array count
 *   - the stanzaId of each element, including those that are nil
 * 
 * @param stream
 *   The associated xmppStream (standard parameter for storage classes)
**/
- (void)setLastDisconnect:(NSDate *)inLastDisconnect
      lastHandledByServer:(uint32_t)inLastHandledByServer
   pendingOutgoingStanzas:(NSArray *)inPendingOutgoingStanzas
                forStream:(XMPPStream *)stream
{
	lastDisconnect = inLastDisconnect;
	lastHandledByServer = inLastHandledByServer;
	pendingOutgoingStanzas = inPendingOutgoingStanzas;
}

/**
 * This method is invoked immediately after an accidental disconnect.
 * And may be invoked post-disconnect if the state changes, such as for the following edge cases:
 * 
 * - due to continued processing of stanzas received pre-disconnect,
 *   that are just now being marked as handled by the delegate(s)
 * - due to a delayed response from the delegate(s),
 *   such that we didn't receive the stanzaId for an outgoing stanza until after the disconnect occurred.
 * 
 * This method is not invoked if stream management is started on a connected xmppStream.
 *
 * @param date
 *   This value will be the actual disconnect date.
 * 
 * @param lastHandledByClient
 *   The most recent 'h' value we can safely send to the server.
 * 
 * @param lastHandledByServer
 *   The most recent 'h' value we've received from the server.
 * 
 * @param pendingOutgoingStanzas
 *   An array of XMPPStreamManagementOutgoingStanza objects.
 *   The storage layer is in charge of properly persisting this array, including:
 *   - the array count
 *   - the stanzaId of each element, including those that are nil
 * 
 * @param stream
 *   The associated xmppStream (standard parameter for storage classes)
**/
- (void)setLastDisconnect:(NSDate *)inLastDisconnect
      lastHandledByClient:(uint32_t)inLastHandledByClient
      lastHandledByServer:(uint32_t)inLastHandledByServer
   pendingOutgoingStanzas:(NSArray *)inPendingOutgoingStanzas
                forStream:(XMPPStream *)stream
{
	lastDisconnect = inLastDisconnect;
	lastHandledByClient = inLastHandledByClient;
	lastHandledByServer = inLastHandledByServer;
	pendingOutgoingStanzas = inPendingOutgoingStanzas;
}

/**
 * Invoked when the extension needs values from a previous session.
 * This method is used to get values needed in order to determine if it can resume a previous stream.
**/
- (void)getResumptionId:(NSString **)resumptionIdPtr
                timeout:(uint32_t *)timeoutPtr
         lastDisconnect:(NSDate **)lastDisconnectPtr
              forStream:(XMPPStream *)stream
{
	if (resumptionIdPtr)   *resumptionIdPtr   = resumptionId;
	if (timeoutPtr)        *timeoutPtr        = timeout;
	if (lastDisconnectPtr) *lastDisconnectPtr = lastDisconnect;
}

/**
 * Invoked when the extension needs values from a previous session.
 * This method is used to get values needed in order to resume a previous stream.
**/
- (void)getLastHandledByClient:(uint32_t *)lastHandledByClientPtr
           lastHandledByServer:(uint32_t *)lastHandledByServerPtr
        pendingOutgoingStanzas:(NSArray **)pendingOutgoingStanzasPtr
                     forStream:(XMPPStream *)stream;
{
	if (lastHandledByClientPtr)    *lastHandledByClientPtr    = lastHandledByClient;
	if (lastHandledByServerPtr)    *lastHandledByServerPtr    = lastHandledByServer;
	if (pendingOutgoingStanzasPtr) *pendingOutgoingStanzasPtr = pendingOutgoingStanzas;
}

/**
 * Instructs the storage layer to remove all values stored for the given stream.
 * This occurs after the extension detects a "cleanly closed stream",
 * in which case the stream cannot be resumed next time.
**/
- (void)removeAllForStream:(XMPPStream *)stream
{
	resumptionId = nil;
	timeout = 0;
	
	lastDisconnect = nil;
	lastHandledByClient = 0;
	lastHandledByServer = 0;
	pendingOutgoingStanzas = nil;
}

@end
