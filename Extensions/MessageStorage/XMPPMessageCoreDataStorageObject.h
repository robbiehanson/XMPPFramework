#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

@class XMPPJID, XMPPMessage;

typedef NS_ENUM(int16_t, XMPPMessageDirection) {
    /// A value indicating that the message's origin is not defined.
    XMPPMessageDirectionUnspecified,
    /// A value indicating that the message has been received from the stream.
    XMPPMessageDirectionIncoming,
    /// A value indicating that the message is originating from the device.
    XMPPMessageDirectionOutgoing
};

typedef NS_ENUM(int16_t, XMPPMessageType) {
    /// A value indicating normal message type as per RFC 3921/6121
    XMPPMessageTypeNormal,
    /// A value indicating chat message type as per RFC 3921/6121
    XMPPMessageTypeChat,
    /// A value indicating error message type as per RFC 3921/6121
    XMPPMessageTypeError,
    /// A value indicating groupchat message type as per RFC 3921/6121
    XMPPMessageTypeGroupchat,
    /// A value indicating headline message type as per RFC 3921/6121
    XMPPMessageTypeHeadline
};

/**
 An object storing the core XMPP message properties defined in RFC 3921/6121.
 
 @see XMPPMessageCoreDataStorage
 @see XMPPMessageContextCoreDataStorageObject
 @see XMPPMessageContextItemCoreDataStorageObject
 */
@interface XMPPMessageCoreDataStorageObject : NSManagedObject

/// The value of "from" attribute (transient).
@property (nonatomic, strong, nullable) XMPPJID *fromJID;

/// The value of "to" attribute (transient).
@property (nonatomic, strong, nullable) XMPPJID *toJID;

/// The contents of "body" child element.
@property (nonatomic, copy, nullable) NSString *body;

/// The value of "id" attribute.
@property (nonatomic, copy, nullable) NSString *stanzaID;

/// The contents of "subject" child element.
@property (nonatomic, copy, nullable) NSString *subject;

/// The contents of "thread" child element.
@property (nonatomic, copy, nullable) NSString *thread;

/// The transmission direction from client's point of view.
@property (nonatomic, assign) XMPPMessageDirection direction;

/// The value of "type" attribute.
@property (nonatomic, assign) XMPPMessageType type;

/// @brief Returns the XML representation of the message including only the core RFC 3921/6121 properties.
/// @discussion Applications employing store-then-send approach to messaging can use this method to obtain the seed of an outgoing message stanza they later decorate with extension-derived values.
- (XMPPMessage *)coreMessage;

/**
 Records a unique outgoing XMPP stream element event ID for the message.
 
 After recording the ID, the application should use the @c sendElement:registeringEventWithID:andGetReceipt: method to send the message, providing the recorded value.
 This way, modules will be able to track the message in their stream callbacks and update the storage accordingly.
 
 This method will trigger an assertion unless invoked on an outgoing message. It will also trigger an assertion if called more than once per actual transmission attempt.
 */
- (void)registerOutgoingMessageStreamEventID:(NSString *)outgoingMessageStreamEventID;

/// @brief Returns the local stream JID for the most recent stream element event associated with the message.
/// @discussion Incoming messages always have a single stream element event associated with them. Outgoing messages can have 0 or more, one per each transmission attempt.
- (nullable XMPPJID *)streamJID;

/// @brief Returns the timestamp for the most recent stream element event associated with the message.
/// @discussion Incoming messages always have a single stream element event associated with them. Outgoing messages can have 0 or more, one per each transmission attempt.
- (nullable NSDate *)streamTimestamp;

@end

NS_ASSUME_NONNULL_END
