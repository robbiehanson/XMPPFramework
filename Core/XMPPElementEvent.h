#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class XMPPJID;

/**
 * A handle that allows identifying elements sent or received in the stream across different delegates
 * and tracking their processing progress.
 *
 * While the core XMPP specification does not require stanzas to be uniquely identifiable, you may still want to
 * identify them internally across different modules or trace the sent ones to the respective send result delegate callbacks.
 *
 * An instance of this class is provided in the context of execution of any of the @c didSendXXX/didFailToSendXXX/didReceiveXXX
 * stream delegate methods. It is retrieved from the @c currentElementEvent property on the calling stream.
 * The delegates can then use it to:
 * - identify the corresponding XMPP stanzas.
 * - be notified of asynchronous processing completion for a given XMPP stanza.
 *
 * Using @c XMPPElementEvent handles is a more robust approach than relying on pointer equality of @c XMPPElement instances.
 */
@interface XMPPElementEvent : NSObject

/// The universally unique identifier of the event that provides the internal identity of the corresponding XMPP stanza.
@property (nonatomic, copy, readonly) NSString *uniqueID;

/// The value of the stream's @c myJID property at the time when the event occured.
@property (nonatomic, strong, readonly, nullable) XMPPJID *myJID;

/// The local device time when the event occured.
@property (nonatomic, strong, readonly) NSDate *timestamp;

/**
 * A flag indicating whether all delegates are done processing the given event.
 *
 * Supports Key-Value Observing. Change notifications are emitted on the stream queue.
 *
 * @see beginDelayedProcessing
 * @see endDelayedProcessingWithToken
 */
@property (nonatomic, assign, readonly) BOOL isProcessingCompleted;

// Instances are created by the stream only.
- (instancetype)init NS_UNAVAILABLE;

/**
 * Marks the event as being asynchronously processed by a delegate and returns a completion token.
 *
 * Event processing is completed after every @c beginDelayedProcessing call has been followed
 * by @c endDelayedProcessingWithToken: with a matching completion token.
 *
 * Unpaired invocations may lead to undefined behavior or stalled events.
 *
 * Events that are not marked for asynchronous processing by any of the delegates complete immediately
 * after control returns from all callbacks.
 *
 * @see endDelayedProcessingWithToken:
 * @see isProcessingCompleted
 */
- (id)beginDelayedProcessing;

/**
 * Marks an end of the previously initiated asynchronous delegate processing.
 *
 * Event processing is completed after every @c beginDelayedProcessing call has been followed
 * by @c endDelayedProcessingWithToken: with a matching completion token.
 *
 * Unpaired invocations may lead to undefined behavior or stalled events.
 *
 * Events that are not marked for asynchronous processing by any of the delegates complete immediately
 * after control returns from all callbacks.
 *
 * @see beginDelayedProcessing
 * @see isProcessingCompleted
 */
- (void)endDelayedProcessingWithToken:(id)delayedProcessingToken;

@end

NS_ASSUME_NONNULL_END
