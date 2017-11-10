#import "XMPPMessageCoreDataStorageObject.h"
#import "XMPPMessageContextCoreDataStorageObject+Protected.h"
#import "XMPPMessageContextItemCoreDataStorageObject+Protected.h"

NS_ASSUME_NONNULL_BEGIN

/// An API to be used by modules to manipulate auxiliary context objects assigned to a stored message.
@interface XMPPMessageCoreDataStorageObject (ContextHelpers)

/// Inserts a new context element associated with the message.
- (XMPPMessageContextCoreDataStorageObject *)appendContextElement;

/**
 @brief Enumerates the message's context elements until the lookup block returns a non-nil value and returns that value.
 @discussion This method expects the lookup block to only return a non-nil value for a single element and will trigger an assertion otherwise.
 */
- (nullable id)lookupInContextWithBlock:(id __nullable (^)(XMPPMessageContextCoreDataStorageObject *contextElement))lookupBlock;

@end

/// An API to be used by modules to manipulate auxiliary context object values assigned to a stored message.
@interface XMPPMessageContextCoreDataStorageObject (ContextHelpers)

/// Inserts a new JID value associated with the context element.
- (XMPPMessageContextJIDItemCoreDataStorageObject *)appendJIDItemWithTag:(XMPPMessageContextJIDItemTag)tag value:(XMPPJID *)value;

/// Inserts a new marker associated with the context element.
- (XMPPMessageContextMarkerItemCoreDataStorageObject *)appendMarkerItemWithTag:(XMPPMessageContextMarkerItemTag)tag;

/// Inserts a new string value associated with the context element.
- (XMPPMessageContextStringItemCoreDataStorageObject *)appendStringItemWithTag:(XMPPMessageContextStringItemTag)tag value:(NSString *)value;

/// Inserts a new timestamp value associated with the context element.
- (XMPPMessageContextTimestampItemCoreDataStorageObject *)appendTimestampItemWithTag:(XMPPMessageContextTimestampItemTag)tag value:(NSDate *)value;

/// Removes all JID values with the given tag associated with the context element.
- (void)removeJIDItemsWithTag:(XMPPMessageContextJIDItemTag)tag;

/// Removes all markers with the given tag associated with the context element.
- (void)removeMarkerItemsWithTag:(XMPPMessageContextMarkerItemTag)tag;

/// Removes all string values with the given tag associated with the context element.
- (void)removeStringItemsWithTag:(XMPPMessageContextStringItemTag)tag;

/// Removes all timestamp values with the given tag associated with the context element.
- (void)removeTimestampItemsWithTag:(XMPPMessageContextTimestampItemTag)tag;

/// Returns all JID values with the given tag associated with the context element.
- (NSSet<XMPPJID *> *)jidItemValuesForTag:(XMPPMessageContextJIDItemTag)tag;

/// @brief Returns the unique JID value with the given tag associated with the context element.
/// @discussion Will trigger an assertion if there is more than one matching value.
- (nullable XMPPJID *)jidItemValueForTag:(XMPPMessageContextJIDItemTag)tag;

/// Returns the number of markers with the given tag associated with the context element.
- (NSInteger)markerItemCountForTag:(XMPPMessageContextMarkerItemTag)tag;

/// @brief Tests whether there is a marker with the given tag associated with the context element.
/// @discussion Will trigger an assertion if there is more than one matching marker.
- (BOOL)hasMarkerItemForTag:(XMPPMessageContextMarkerItemTag)tag;

/// Returns all string values with the given tag associated with the context element.
- (NSSet<NSString *> *)stringItemValuesForTag:(XMPPMessageContextStringItemTag)tag;

/// @brief Returns the unique string value with the given tag associated with the context element.
/// @discussion Will trigger an assertion if there is more than one matching value.
- (nullable NSString *)stringItemValueForTag:(XMPPMessageContextStringItemTag)tag;

/// Returns all timestamp values with the given tag associated with the context element.
- (NSSet<NSDate *> *)timestampItemValuesForTag:(XMPPMessageContextTimestampItemTag)tag;

/// @brief Returns the unique timestamp value with the given tag associated with the context element.
/// @discussion Will trigger an assertion if there is more than one matching value.
- (nullable NSDate *)timestampItemValueForTag:(XMPPMessageContextTimestampItemTag)tag;

@end

NS_ASSUME_NONNULL_END
