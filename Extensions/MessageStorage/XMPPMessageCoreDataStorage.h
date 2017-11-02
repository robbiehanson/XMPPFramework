#import "XMPPCoreDataStorage.h"

NS_ASSUME_NONNULL_BEGIN

@class XMPPMessageCoreDataStorageObject, XMPPElementEvent, XMPPMessageCoreDataStorageTransaction;

/**
 A client message storage implementation that supports per-module extensibility while maintaining a fixed underlying Core Data model.
 
 The design is based on assigning auxiliary context objects to each stored XMPP message. Those context objects aggregate arbitrary sets of tagged primitive values.
 By defining their own context aggregations and value tags, modules can extend storage capabilities and expose them via a simple API using categories on the core classes.
 
 The application-facing API consists of the main interface and any categories provided by module authors. The protected interface provides module helper methods.
 
 @see XMPPMessageCoreDataStorageObject
 */
@interface XMPPMessageCoreDataStorage : XMPPCoreDataStorage

/// Inserts a core message storage object into the application-facing (main thread) managed object context.
- (XMPPMessageCoreDataStorageObject *)insertOutgoingMessageStorageObject;

/**
 Provides a storage transaction for processing an incoming message stream event on a background thread managed object context.
 
 A new incoming direction storage object will be inserted and stream event properties registered on it before it is provided to update blocks.
 The transaction will trigger an assertion if a message storage object registered for the provided stream event already exists.
 
 Callers should perform all actions on the provided transaction immediately in the handler block.
 Attempts to store and access it later will trigger an assertion.
 */
- (void)provideTransactionForIncomingMessageEvent:(XMPPElementEvent *)event withHandler:(void (^)(XMPPMessageCoreDataStorageTransaction *transaction))handler;

/**
 Provides a storage transaction for processing an outgoing message stream event on a background thread managed object context.
 
 A previously inserted outgoing direction storage object will be looked up and stream event properties registered on it
 before it is provided to update blocks.
 It is assumed that the application had registered the respective stream event ID using @c registerOutgoingMessageStreamEventID: before sending the message,
 otherwise an assertion will be triggered.
 
 Callers should perform all actions on the provided transaction immediately in the handler block.
 Attempts to store and access it later will trigger an assertion.
 */
- (void)provideTransactionForOutgoingMessageEvent:(XMPPElementEvent *)event withHandler:(void (^)(XMPPMessageCoreDataStorageTransaction *transaction))handler;

@end

/**
 An object that manages storage updates associated with a single message stream event.
 
 The actions are enqueued to be performed as a single batch once the given event has been processed by all modules.
 This way, the main thread context never sees a message that has only been partially processed. It is particularly important when handling XMPP extensions
 that affect temporal ordering or replace messages (e.g. delayed delivery, last message correction).
 */
@interface XMPPMessageCoreDataStorageTransaction : NSObject

// Transaction lifetime is managed by the storage.
- (instancetype)init NS_UNAVAILABLE;

/// Enqueues actions to be performed on a corresponding storage object in response to a message stream event.
- (void)scheduleStorageUpdateWithBlock:(void (^)(XMPPMessageCoreDataStorageObject *messageObject))block;

@end

NS_ASSUME_NONNULL_END
