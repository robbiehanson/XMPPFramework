#import "XMPPMessageContextCoreDataStorageObject.h"

NS_ASSUME_NONNULL_BEGIN

@class XMPPMessageCoreDataStorageObject, XMPPMessageContextJIDItemCoreDataStorageObject, XMPPMessageContextMarkerItemCoreDataStorageObject, XMPPMessageContextStringItemCoreDataStorageObject, XMPPMessageContextTimestampItemCoreDataStorageObject;

@interface XMPPMessageContextCoreDataStorageObject (Protected)

/// The message the context object is assigned to.
@property (nonatomic, strong, nullable) XMPPMessageCoreDataStorageObject *message;

/// The JID values aggregated by the context object.
@property (nonatomic, copy, nullable) NSSet<XMPPMessageContextJIDItemCoreDataStorageObject *> *jidItems;

/// The markers aggregated by the context object.
@property (nonatomic, copy, nullable) NSSet<XMPPMessageContextMarkerItemCoreDataStorageObject *> *markerItems;

/// The string values aggregated by the context object.
@property (nonatomic, copy, nullable) NSSet<XMPPMessageContextStringItemCoreDataStorageObject *> *stringItems;

/// The timestamp values aggregated by the context object.
@property (nonatomic, copy, nullable) NSSet<XMPPMessageContextTimestampItemCoreDataStorageObject *> *timestampItems;

@end

@interface XMPPMessageContextCoreDataStorageObject (CoreDataGeneratedRelationshipAccesssors)

- (void)addJidItemsObject:(XMPPMessageContextJIDItemCoreDataStorageObject *)value;
- (void)removeJidItemsObject:(XMPPMessageContextJIDItemCoreDataStorageObject *)value;
- (void)addJidItems:(NSSet<XMPPMessageContextJIDItemCoreDataStorageObject *> *)value;
- (void)removeJidItems:(NSSet<XMPPMessageContextJIDItemCoreDataStorageObject *> *)value;

- (void)addMarkerItemsObject:(XMPPMessageContextMarkerItemCoreDataStorageObject *)value;
- (void)removeMarkerItemsObject:(XMPPMessageContextMarkerItemCoreDataStorageObject *)value;
- (void)addMarkerItems:(NSSet<XMPPMessageContextMarkerItemCoreDataStorageObject *> *)value;
- (void)removeMarkerItems:(NSSet<XMPPMessageContextMarkerItemCoreDataStorageObject *> *)value;

- (void)addStringItemsObject:(XMPPMessageContextStringItemCoreDataStorageObject *)value;
- (void)removeStringItemsObject:(XMPPMessageContextStringItemCoreDataStorageObject *)value;
- (void)addStringItems:(NSSet<XMPPMessageContextStringItemCoreDataStorageObject *> *)value;
- (void)removeStringItems:(NSSet<XMPPMessageContextStringItemCoreDataStorageObject *> *)value;

- (void)addTimestampItemsObject:(XMPPMessageContextTimestampItemCoreDataStorageObject *)value;
- (void)removeTimestampItemsObject:(XMPPMessageContextTimestampItemCoreDataStorageObject *)value;
- (void)addTimestampItems:(NSSet<XMPPMessageContextTimestampItemCoreDataStorageObject *> *)value;
- (void)removeTimestampItems:(NSSet<XMPPMessageContextTimestampItemCoreDataStorageObject *> *)value;

@end

NS_ASSUME_NONNULL_END
