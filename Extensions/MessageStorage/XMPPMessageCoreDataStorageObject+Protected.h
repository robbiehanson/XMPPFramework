#import "XMPPMessageCoreDataStorageObject.h"

NS_ASSUME_NONNULL_BEGIN

@class XMPPMessageContextCoreDataStorageObject;

/// An API to be used by modules to manipulate core message objects.
@interface XMPPMessageCoreDataStorageObject (Protected)

/// The persistent attribute storing the domain component of @c fromJID property.
@property (nonatomic, copy, nullable) NSString *fromDomain;

/// The persistent attribute storing the resource component of @c fromJID property.
@property (nonatomic, copy, nullable) NSString *fromResource;

/// The persistent attribute storing the user component of @c fromJID property.
@property (nonatomic, copy, nullable) NSString *fromUser;

/// The persistent attribute storing the domain component of @c toJID property.
@property (nonatomic, copy, nullable) NSString *toDomain;

/// The persistent attribute storing the resource component of @c toJID property.
@property (nonatomic, copy, nullable) NSString *toResource;

/// The persistent attribute storing the user component of @c toJID property.
@property (nonatomic, copy, nullable) NSString *toUser;

/// The auxiliary context objects assigned to the message.
@property (nonatomic, copy, nullable) NSSet<XMPPMessageContextCoreDataStorageObject *> *contextElements;

/// @brief Returns the message object from the given context that has a stream element event with the given ID recorded.
/// @discussion As the stream element event IDs are expected to be unique, this method will trigger an assertion if more than one matching object is found.
+ (nullable XMPPMessageCoreDataStorageObject *)findWithStreamEventID:(NSString *)streamEventID
                                              inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

/// @brief Records stream element event properties for the incoming message.
/// @discussion This method will trigger an assertion unless invoked on an incoming message. It will also trigger an assertion when invoked more than once.
- (void)registerIncomingMessageStreamEventID:(NSString *)streamEventID
                                   streamJID:(XMPPJID *)streamJID
                        streamEventTimestamp:(NSDate *)streamEventTimestamp;

/// @brief Records the core RFC 3921/6121 properties of an incoming message from the given XML representation.
/// @discussion This method will trigger an assertion unless invoked on an incoming message. Subsequent invocations will overwrite previous values.
- (void)registerIncomingMessageCore:(XMPPMessage *)message;

/**
 Records stream element event properties for the sent message that has a pending outgoing event registration.
 
 This method will trigger an assertion unless invoked on an outgoing message.
 It will also trigger an assertion if not matched with a prior @c registerOutgoingMessageStreamEventID: invocation.
 */
- (void)registerOutgoingMessageStreamJID:(XMPPJID *)streamJID streamEventTimestamp:(NSDate *)streamEventTimestamp;

/**
 Retires the current stream element event timestamp or marks the initial timestamp for retirement if no timestamp is currently registered.
 
 A single message object can be associated with multiple timestamps, e.g. there can be several transmission attempts for an outgoing message
 or a message can have both stream timestamp and delayed delivery timestamp assigned.
 
 At the same time, a common application use case involves fetching temporally ordered messages. In terms of the message storage Core Data model,
 this translates to fetching timestamp context values with specific tags and then looking up the message objects they are attached to.
 
 For this approach to work, there needs to be at most one timestamp per message that meets the fetch criteria; retiring stream timestamps allows to exclude duplicates.
 */
- (void)retireStreamTimestamp;

@end

@interface XMPPMessageCoreDataStorageObject (CoreDataGeneratedRelationshipAccesssors)

- (void)addContextElementsObject:(XMPPMessageContextCoreDataStorageObject *)value;
- (void)removeContextElementsObject:(XMPPMessageContextCoreDataStorageObject *)value;
- (void)addContextElements:(NSSet<XMPPMessageContextCoreDataStorageObject *> *)value;
- (void)removeContextElements:(NSSet<XMPPMessageContextCoreDataStorageObject *> *)value;

@end

NS_ASSUME_NONNULL_END
