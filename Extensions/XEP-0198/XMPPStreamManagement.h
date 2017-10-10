#import <Foundation/Foundation.h>
#import "XMPP.h"

#define _XMPP_STREAM_MANAGEMENT_H

@protocol XMPPStreamManagementStorage;
@class XMPPStreamManagementOutgoingStanza;

NS_ASSUME_NONNULL_BEGIN
@interface XMPPStreamManagement : XMPPModule <XMPPCustomBinding>

/**
 * The XMPPStreamManagement extension implements XEP-0198:
 * http://xmpp.org/extensions/xep-0198.html
 *
 * @param storage
 *   You must configure the extension with a storage module.
 *   A persistent storage layer is recommended for distribution.
 *   For testing, or if you're not planning on using stream resumption, then the memory storage solution will work.
 * 
 * @param queue
 *   The standard dispatch_queue option, with which to run the extension on.
**/
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithDispatchQueue:(nullable dispatch_queue_t)queue NS_UNAVAILABLE;
- (instancetype)initWithStorage:(id <XMPPStreamManagementStorage>)storage;
- (instancetype)initWithStorage:(id <XMPPStreamManagementStorage>)storage dispatchQueue:(nullable dispatch_queue_t)queue NS_DESIGNATED_INITIALIZER;

@property (nonatomic, strong, readonly) id <XMPPStreamManagementStorage> storage;

#pragma mark Enable

/**
 * This method sends the <enable> stanza to the server to request enabling stream management.
 *
 * XEP-0198 specifies that the <enable> stanza should only be sent by clients after authentication,
 * and after binding has occurred.
 * 
 * The servers response is reported via the delegate methods:
 * @see xmppStreamManagement:wasEnabled:
 * @see xmppStreamManagement:wasNotEnabled:
 *
 * @param supportsResumption
 *   Whether the client should request resumptions support.
 *   If YES, the resume attribute will be included. E.g. <enable resume='true'/>
 * 
 * @param maxTimeout
 *   Allows you to specify the client's preferred maximum resumption time.
 *   This is optional, and will only be sent if you provide a positive value (maxTimeout > 0.0).
 *   Note that XEP-0198 only supports sending this value in seconds.
 *   So it the provided maxTimeout includes millisecond precision, this will be ignored via truncation
 *   (rounding down to nearest whole seconds value).
 * 
 * @see supportsStreamManagement
**/
- (void)enableStreamManagementWithResumption:(BOOL)supportsResumption maxTimeout:(NSTimeInterval)maxTimeout;

#pragma mark Resume

/**
 * If set to YES, then the extension will automatically attempt to resume any sessions that appear resumable.
 *
 * That is, if the canResumeStream method would return YES, then the module will automatically plug into the xmppStream,
 * and attempts to resume the session. If the attempt fails, the xmppStream will automatically fall back to
 * the standard binding process.
 *
 * Remember: If the extension does not believe that resumption is possible, then it won't attempt to resume.
 * That is, if it doesn't have data in storage that matches the current connection, or the data is expired,
 * then it allows the xmppStream to perform standard binding immediately, without attempting to resume.
 *
 * If you wish to handle stream resumption manually, then you can simply implement xmppStreamWillBind:,
 * and return this extension instance according to your own conditions.
 * 
 * In order to determine if a stream was resumed, you should invoke didResumeWithAckedStanzaIds:serverResponse:
 * from within the xmppStreamDidAuthenticate: callback.
 *
 * The default value is NO.
**/
@property (atomic, readwrite) BOOL autoResume;

/**
 * This method is meant to be called by other extensions when they receive an xmppStreamDidAuthenticate callback.
 * 
 * Returns YES if the stream was resumed during the authentication process.
 * Returns NO otherwise (if resume wasn't available, or it failed).
 * 
 * Other extensions may wish to skip certain setup processes that aren't
 * needed if the stream was resumed (since the previous session state has been restored server-side).
**/
@property (atomic, readonly) BOOL didResume;

/**
 * This method is meant to be called when you receive an xmppStreamDidAuthenticate callback.
 *
 * It is used instead of a standard delegate method in order to provide a cleaner API.
 * By using this method, one can put all the logic for handling authentication in a single place.
 * But more importantly, it solves several subtle timing and threading issues.
 *
 * > A delegate method could have hit either before or after xmppStreamDidAuthenticate, depending on thread scheduling.
 * > We could have queued it up, and forced it to hit after.
 * > But your code would likely still have needed to add a check within xmppStreamDidAuthenticate...
 *
 * @param stanzaIdsPtr (optional)
 *   Just like the stanzaIdsPtr provided in xmppStreamManagement:didReceiveAckForStanzaIds:.
 *   This comes from the h value provided within the <resumed h='X'/> stanza sent by the server.
 * 
 * @param responsePtr (optional)
 *   Returns the response we got from the server. Either <resumed/> or <failed/>.
 *   This will be nil if resume wasn't tried.
 * 
 * @return
 *   YES if the stream was resumed.
 *   NO otherwise.
**/
- (BOOL)didResumeWithAckedStanzaIds:(NSArray<id> * _Nullable * _Nullable)stanzaIdsPtr
					 serverResponse:(NSXMLElement * _Nullable * _Nullable)responsePtr;

/**
 * Returns YES if the stream can be resumed.
 * 
 * This would be the case if there's an available resumptionId for the authenticated xmppStream,
 * and the timeout from the last stream has not been exceeded.
**/
- (BOOL)canResumeStream;


#pragma mark Requesting Acks

/**
 * Sends a request <r/> element, requesting the server reply with an ack <a h='lastHandled'/>.
 * 
 * You can also configure the extension to automatically sends requests.
 * @see automaticallyRequestAcksAfterStanzaCount:orTimeout:
 *
 * When the server replies with an ack, the delegate method will be invoked.
 * @see xmppStreamManagement:didReceiveAckForStanzaIds:
**/
- (void)requestAck;

/**
 * The module can be configured to automatically request acks (send <r/>) based on your criteria.
 * The algorithm to do this takes into account:
 *
 * - The number of stanzas that have been sent since the last request was sent.
 * - The amount of time that has elapsed since the first stanza (after the last request) was sent.
 * 
 * So, for example, if you set the stanzaCount to 5, and the timeout to 2.0 seconds then:
 * - Sending 5 stanzas back-to-back will automatically trigger an outgoing request
 * - Sending 1 stanza will automatically trigger an outgoing request to be sent 2.0 seconds later,
 *   which will get preempted if 4 more stanzas are sent before the 2.0 second timer expires.
 * 
 * In other words, whichever event takes place FIRST will trigger the request to be sent.
 * 
 * You can disable either trigger by setting its value to zero.
 * So, for example, if you only want to use a timeout of 5 seconds,
 * then you could set the stanzaCount to zero and the timeout to 5 seconds.
 *
 * @param stanzaCount
 *   The stanzaCount to use for the auto request algorithm.
 *   If stanzaCount is zero, then the number of stanzas will be ignored in the algorithm.
 *
 * @param timeout
 *   The timeout to use for the auto request algorithm.
 *   If the timeout is zero (or negative), then the timer will be ignored in the algorithm.
 *
 * The default stanzaCount is 0 (disabled).
 * The default timeout is 0.0 seconds (disabled).
**/
- (void)automaticallyRequestAcksAfterStanzaCount:(NSUInteger)stanzaCount orTimeout:(NSTimeInterval)timeout;

/**
 * Returns the current auto-request configuration.
 *
 * @see automaticallyRequestAcksAfterStanzaCount:orTimeout:
**/
- (void)getAutomaticallyRequestAcksAfterStanzaCount:(NSUInteger * _Nullable)stanzaCountPtr orTimeout:(NSTimeInterval * _Nullable)timeoutPtr;


#pragma mark Sending Acks

/**
 * Sends an unrequested ack <a h='lastHandled'/> element, acking the server's recently received (and handled) elements.
 *
 * You can also configure the extension to automatically sends acks.
 * @see automaticallySendAcksAfterStanzaCount:orTimeout:
 * 
 * Keep in mind that the extension will automatically send an ack if it receives an explicit request.
**/
- (void)sendAck;

/**
 * The module can be configured to automatically send unrequested acks.
 * That is, rather than waiting to receive explicit requests <r/> from the server,
 * the client automatically sends them based on configurable criteria.
 * 
 * The algorithm to do this takes into account:
 *
 * - The number of stanzas that have been received since the last ack was sent.
 * - The amount of time that has elapsed since the first stanza (after the last ack) was received.
 * 
 * In other words, whichever event takes place FIRST will trigger the request to be sent.
 * You can disable either trigger by setting its value to zero.
 * 
 * As would be expected, if you manually send an unrequested ack (via the sendAck method),
 * or if an ack is sent out in response to a received request </r> from the server,
 * then the stanzaCount & timeout are reset.
 *
 * @param stanzaCount
 *   The stanzaCount to use for the auto ack algorithm.
 *   If stanzaCount is zero, then the number of stanzas will be ignored in the algorithm.
 * 
 * @param timeout
 *   The timeout to sue fo the auto ack algorithm.
 *   If the timeout is zero (or negative), then the timer will be ignored in the algorithm.
 * 
 * The default stanzaCount is 0 (disabled).
 * The default timeout is 0.0 seconds (disabled).
**/
- (void)automaticallySendAcksAfterStanzaCount:(NSUInteger)stanzaCount orTimeout:(NSTimeInterval)timeout;

/**
 * Returns the current "auto-send unrequested acks" configuration.
 * 
 * @see automaticallySendAcksAfterStanzaCount:orTimeout:
**/
- (void)getAutomaticallySendAcksAfterStanzaCount:(NSUInteger * _Nullable)stanzaCountPtr orTimeout:(NSTimeInterval * _Nullable)timeoutPtr;

/**
 * If an explicit request <r/> is received from the server, should we delay sending the ack <a/> ?
 * From XEP-0198 :
 * 
 * > When an <r/> element ("request") is received, the recipient MUST acknowledge it by sending an <a/> element
 * > to the sender containing a value of 'h' that is equal to the number of stanzas handled by the recipient of
 * > the <r/> element. The response SHOULD be sent as soon as possible after receiving the <r/> element,
 * > and MUST NOT be withheld for any condition other than a timeout. For example, a client with a slow connection
 * > might want to collect many stanzas over a period of time before acking, and a server might want to throttle
 * > incoming stanzas.
 * 
 * Thus the XEP recommends that you do not use a delay.
 * However, it acknowledges that there may be certain situations in which a delay could prove helpful.
 *
 * The default value is 0.0 (as recommended by XEP-0198)
**/
@property (atomic, assign, readwrite) NSTimeInterval ackResponseDelay;

/**
 * It's critically important to understand what an ACK means.
 *
 * Every ACK contains an 'h' attribute, which stands for "handled".
 * To paraphrase XEP-0198 (in client-side terminology):
 * 
 *   Acknowledging a previously ­received element indicates that the stanza has been "handled" by the client.
 *   By "handled" we mean that the client has successfully processed the stanza
 *   (including possibly saving the item to the database if needed);
 *   Until a stanza has been affirmed as handled by the client, that stanza is the responsibility of the server
 *   (e.g., to resend it or generate an error if it is never affirmed as handled by the client).
 * 
 * This means that if your processing of certain elements includes saving them to a database,
 * then you should not mark those elements as handled until after your database has confirmed the data is on disk.
 * 
 * You should note that this is a critical component of any networking app that claims to have "reliable messaging".
 * 
 * By default, all elements will be marked as handled as soon as they arrive.
 * You'll want to override the default behavior for important elements that require proper handling by your app.
 * For example, messages that need to be saved to the database.
 * Here's how to do so:
 * 
 * - Implement the delegate method xmppStreamManagement:getIsHandled:stanzaId:forReceivedElement:
 *
 *   This method is invoked for all received elements.
 *   You can inspect the element, and if it is important and requires special handling by the app,
 *   then flag the element as NOT handled (overriding the default).
 *   Also assign the element a "stanzaId". This can be anything you want, such as the elementID,
 *   or maybe something more app-specific (e.g. something you already use that's associated with the message).
 * 
 * - Handle the important element however you need to
 * 
 *   If you're saving something to the database,
 *   then wait until after the database commit has completed successfully.
 *
 * - Notify the module that the element has been handled via the method markHandledStanzaId:
 * 
 *   You must pass the stanzaId that you returned from the delegate method.
 *
 * 
 * @see xmppStreamManagement:getIsHandled:stanzaId:forReceivedElement:
**/
- (void)markHandledStanzaId:(id)stanzaId;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol XMPPStreamManagementDelegate
@optional

/**
 * Notifies delegates of the server's response from sending the <enable> stanza.
**/
- (void)xmppStreamManagement:(XMPPStreamManagement *)sender wasEnabled:(NSXMLElement *)enabled;
- (void)xmppStreamManagement:(XMPPStreamManagement *)sender wasNotEnabled:(NSXMLElement *)failed;

/**
 * Notifies delegates that a request <r/> for an ack from the server was sent.
**/
- (void)xmppStreamManagementDidRequestAck:(XMPPStreamManagement *)sender;

/**
 * Invoked when an ack is received from the server, and new stanzas have been acked.
 * 
 * @param stanzaIds
 *   Includes all "stanzaIds" of sent elements that were just acked.
 *
 * What is a "stanzaId" ?
 * 
 * A stanzaId is a unique identifier that ** YOU can provide ** in order to track an element.
 * It could simply be the elementId of the sent element. Or,
 * it could be something custom that you provide in order to properly lookup a message in your data store.
 * 
 * For more information, see the delegate method xmppStreamManagement:stanzaIdForSentElement:
**/
- (void)xmppStreamManagement:(XMPPStreamManagement *)sender didReceiveAckForStanzaIds:(NSArray<id> *)stanzaIds;

/**
 * XEP-0198 reports the following regarding duplicate stanzas:
 *
 *     Because unacknowledged stanzas might have been received by the other party,
 *     resending them might result in duplicates; there is no way to prevent such a
 *     result in this protocol, although use of the XMPP 'id' attribute on all stanzas
 *     can at least assist the intended recipients in weeding out duplicate stanzas.
 * 
 * In other words, there are edge cases in which you might receive duplicates.
 * And the proper way to fix this is to use some kind of identifier in order to detect duplicates.
 * 
 * What kind of identifier to use is up to you. (It's app specific.)
 * The XEP notes that you might use the 'id' attribute for this purpose. And this is certainly the most common case.
 * However, you may have an alternative scheme that works better for your purposes.
 * In which case you can use this delegate method to opt-in.
 * 
 * For example:
 *   You store all your messages in YapDatabase, which is a collection/key/value storage system.
 *   Perhaps the collection is the conversationId, and the key is a messageId.
 *   Therefore, to efficiently lookup a message in your datastore you'd prefer a collection/key tuple.
 *
 *   To achieve this, you would implement this method, and return a YapCollectionKey object for message elements.
 *   This way, when the xmppStreamManagement:didReceiveAckForStanzaIds: method is invoked,
 *   you'll get a list that contains your collection/key tuple objects. And then you can quickly and efficiently
 *   fetch and update your message objects.
 * 
 * If there are no delegates that implement this method,
 * or all delegates return nil, then the stanza's elementId is used as the stanzaId.
 *
 * If the stanza isn't assigned a stanzaId (via a delegate method),
 * and it doesn't have an elementId, then it isn't reported in the acked stanzaIds array.
**/
- (nullable id)xmppStreamManagement:(XMPPStreamManagement *)sender stanzaIdForSentElement:(XMPPElement *)element;

/**
 * It's critically important to understand what an ACK means.
 *
 * Every ACK contains an 'h' attribute, which stands for "handled".
 * To paraphrase XEP-0198 (in client-side terminology):
 *
 *   Acknowledging a previously ­received element indicates that the stanza has been "handled" by the client.
 *   By "handled" we mean that the client has successfully processed the stanza
 *   (including possibly saving the item to the database if needed);
 *   Until a stanza has been affirmed as handled by the client, that stanza is the responsibility of the server
 *   (e.g., to resend it or generate an error if it is never affirmed as handled by the client).
 *
 * This means that if your processing of certain elements includes saving them to a database,
 * then you should not mark those elements as handled until after your database has confirmed the data is on disk.
 *
 * You should note that this is a critical component of any networking app that claims to have "reliable messaging".
 *
 * By default, all elements will be marked as handled as soon as they arrive.
 * You'll want to override the default behavior for important elements that require proper handling by your app.
 * For example, messages that need to be saved to the database.
 * Here's how to do so:
 *
 * - Implement the delegate method xmppStreamManagement:getIsHandled:stanzaId:forReceivedElement:
 *
 *   This method is invoked for all received elements.
 *   You can inspect the element, and if it is important and requires special handling by the app,
 *   then flag the element as NOT handled (overriding the default).
 *   Also assign the element a "stanzaId". This can be anything you want, such as the elementID,
 *   or maybe something more app-specific (e.g. something you already use that's associated with the message).
 *
 * - Handle the important element however you need to
 *
 *   If you're saving something to the database,
 *   then wait until after the database commit has completed successfully.
 *
 * - Notify the module that the element has been handled via the method markHandledStanzaId:
 *
 *   You must pass the stanzaId that you returned from this delegate method.
 *
 *
 * @see markHandledStanzaId:
**/
- (void)xmppStreamManagement:(XMPPStreamManagement *)sender
                getIsHandled:(BOOL * _Nullable)isHandledPtr
                    stanzaId:(id _Nullable * _Nullable)stanzaIdPtr
          forReceivedElement:(XMPPElement *)element;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol XMPPStreamManagementStorage <NSObject>
@required

//
//
// -- PRIVATE METHODS --
//
// These methods are designed to be used ONLY by the XMPPStreamManagement class.
//
//

/**
 * Configures the storage class, passing it's parent and the parent's dispatch queue.
 *
 * This method is called by the init methods of the XMPPStreamManagement class.
 * This method is designed to inform the storage class of it's parent
 * and of the dispatch queue the parent will be operating on.
 *
 * A storage class may choose to operate on the same queue as it's parent,
 * as the majority of the time it will be getting called by the parent.
 * If both are operating on the same queue, the combination may run faster.
 *
 * Some storage classes support multiple xmppStreams,
 * and may choose to operate on their own internal queue.
 *
 * This method should return YES if it was configured properly.
 * It should return NO only if configuration failed.
 * For example, a storage class designed to be used only with a single xmppStream is being added to a second stream.
**/
- (BOOL)configureWithParent:(XMPPStreamManagement *)parent queue:(dispatch_queue_t)queue;

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
- (void)setResumptionId:(nullable NSString *)resumptionId
                timeout:(uint32_t)timeout
         lastDisconnect:(NSDate *)date
              forStream:(XMPPStream *)stream;

/**
 * This method is invoked ** often ** during stream operation.
 * It is not invoked when the xmppStream is disconnected.
 *
 * Important: See the note below: "Optimizing storage demands during active stream usage"
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
- (void)setLastDisconnect:(NSDate *)date
      lastHandledByClient:(uint32_t)lastHandledByClient
                forStream:(XMPPStream *)stream;

/**
 * This method is invoked ** often ** during stream operation.
 * It is not invoked when the xmppStream is disconnected.
 * 
 * Important: See the note below: "Optimizing storage demands during active stream usage"
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
- (void)setLastDisconnect:(NSDate *)date
      lastHandledByServer:(uint32_t)lastHandledByServer
   pendingOutgoingStanzas:(nullable NSArray<XMPPStreamManagementOutgoingStanza*> *)pendingOutgoingStanzas
                forStream:(XMPPStream *)stream;


/// ***** Optimizing storage demands during active stream usage *****
///
/// There are 2 methods that are invoked frequently during stream activity:
///
/// - setLastDisconnect:lastHandledByClient:forStream:
/// - setLastDisconnect:lastHandledByServer:pendingOutgoingStanzas:forStream:
///
/// They are invoked any time the 'h' values change, or whenver the pendingStanzaIds change.
/// In other words, they are invoked continually as stanzas get sent and received.
/// And it is the job of the storage layer to decide how to handle the traffic.
/// There are a few things to consider here:
///
/// - How much chatter does the xmppStream do?
/// - How fast is the storage layer?
/// - How does the overhead on the storage layer affect the rest of the app?
///
/// If your xmppStream isn't very chatty, and you've got a fast concurrent database,
/// then you may be able to simply pipe all these method calls to the database without thinking.
/// However, if your xmppStream is always constantly sending/receiving presence stanzas, and pinging the server,
/// then you might consider a bit of optimzation here. Below is a simple recommendation for how to accomplish this.
///
/// You could choose to queue the changes from these method calls, and dump them to the database after a timeout.
/// Thus you'll be able to consolidate a large traffic surge into a small handful of database operations.
///
/// Also, you could expose a 'flush' operation on the storage layer.
/// And invoke the flush operation when the app is backgrounded, or about to quit.


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
- (void)setLastDisconnect:(NSDate *)date
      lastHandledByClient:(uint32_t)lastHandledByClient
      lastHandledByServer:(uint32_t)lastHandledByServer
   pendingOutgoingStanzas:(nullable NSArray<XMPPStreamManagementOutgoingStanza*> *)pendingOutgoingStanzas
                forStream:(XMPPStream *)stream;

/**
 * Invoked when the extension needs values from a previous session.
 * This method is used to get values needed in order to determine if it can resume a previous stream.
**/
- (void)getResumptionId:(NSString * _Nullable * _Nullable)resumptionIdPtr
                timeout:(uint32_t * _Nullable)timeoutPtr
         lastDisconnect:(NSDate * _Nullable * _Nullable)lastDisconnectPtr
              forStream:(XMPPStream *)stream;

/**
 * Invoked when the extension needs values from a previous session.
 * This method is used to get values needed in order to resume a previous stream.
**/
- (void)getLastHandledByClient:(uint32_t * _Nullable)lastHandledByClientPtr
           lastHandledByServer:(uint32_t * _Nullable)lastHandledByServerPtr
        pendingOutgoingStanzas:(NSArray<XMPPStreamManagementOutgoingStanza*> * _Nullable * _Nullable)pendingOutgoingStanzasPtr
                     forStream:(XMPPStream *)stream;

/**
 * Instructs the storage layer to remove all values stored for the given stream.
 * This occurs after the extension detects a "cleanly closed stream",
 * in which case the stream cannot be resumed next time.
**/
- (void)removeAllForStream:(XMPPStream *)stream;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface XMPPStream (XMPPStreamManagement)

/**
 * Returns whether or not the server's <stream:features> includes <sm xmlns='urn:xmpp:sm:3'/>.
**/
@property (nonatomic, readonly) BOOL supportsStreamManagement;

@end
NS_ASSUME_NONNULL_END
