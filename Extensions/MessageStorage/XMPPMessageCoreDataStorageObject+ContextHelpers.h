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
- (XMPPMessageContextJIDItemCoreDataStorageObject *)appendJIDItemWithTag:(XMPPMessageContextJIDItemTag)tag value:(XMPPJID *)value
NS_SWIFT_NAME(appendJIDItem(with:value:));

/// Inserts a new marker associated with the context element.
- (XMPPMessageContextMarkerItemCoreDataStorageObject *)appendMarkerItemWithTag:(XMPPMessageContextMarkerItemTag)tag
NS_SWIFT_NAME(appendMarkerItem(with:));

/// Inserts a new string value associated with the context element.
- (XMPPMessageContextStringItemCoreDataStorageObject *)appendStringItemWithTag:(XMPPMessageContextStringItemTag)tag value:(NSString *)value
NS_SWIFT_NAME(appendStringItem(with:value:));

/// Inserts a new timestamp value associated with the context element.
- (XMPPMessageContextTimestampItemCoreDataStorageObject *)appendTimestampItemWithTag:(XMPPMessageContextTimestampItemTag)tag value:(NSDate *)value
NS_SWIFT_NAME(appendTimestampItem(with:value:));

/// Removes all JID values with the given tag associated with the context element.
- (void)removeJIDItemsWithTag:(XMPPMessageContextJIDItemTag)tag
NS_SWIFT_NAME(removeJIDItems(with:));

/// Removes all markers with the given tag associated with the context element.
- (void)removeMarkerItemsWithTag:(XMPPMessageContextMarkerItemTag)tag
NS_SWIFT_NAME(removeMarkerItems(with:));

/// Removes all string values with the given tag associated with the context element.
- (void)removeStringItemsWithTag:(XMPPMessageContextStringItemTag)tag
NS_SWIFT_NAME(removeStringItems(with:));

/// Removes all timestamp values with the given tag associated with the context element.
- (void)removeTimestampItemsWithTag:(XMPPMessageContextTimestampItemTag)tag
NS_SWIFT_NAME(removeTimestampItems(with:));

/// Returns all JID values with the given tag associated with the context element.
- (NSSet<XMPPJID *> *)jidItemValuesForTag:(XMPPMessageContextJIDItemTag)tag
NS_SWIFT_NAME(jidItemValues(for:));

/// @brief Returns the unique JID value with the given tag associated with the context element.
/// @discussion Will trigger an assertion if there is more than one matching value.
- (nullable XMPPJID *)jidItemValueForTag:(XMPPMessageContextJIDItemTag)tag
NS_SWIFT_NAME(jidItemValue(for:));

/// Returns the number of markers with the given tag associated with the context element.
- (NSInteger)markerItemCountForTag:(XMPPMessageContextMarkerItemTag)tag
NS_SWIFT_NAME(markerItemCount(for:));

/// @brief Tests whether there is a marker with the given tag associated with the context element.
/// @discussion Will trigger an assertion if there is more than one matching marker.
- (BOOL)hasMarkerItemForTag:(XMPPMessageContextMarkerItemTag)tag
NS_SWIFT_NAME(hasMarkerItem(for:));

/// Returns all string values with the given tag associated with the context element.
- (NSSet<NSString *> *)stringItemValuesForTag:(XMPPMessageContextStringItemTag)tag
NS_SWIFT_NAME(stringItemValues(for:));

/// @brief Returns the unique string value with the given tag associated with the context element.
/// @discussion Will trigger an assertion if there is more than one matching value.
- (nullable NSString *)stringItemValueForTag:(XMPPMessageContextStringItemTag)tag
NS_SWIFT_NAME(stringItemValue(for:));

/// Returns all timestamp values with the given tag associated with the context element.
- (NSSet<NSDate *> *)timestampItemValuesForTag:(XMPPMessageContextTimestampItemTag)tag
NS_SWIFT_NAME(timestampItemValues(for:));

/// @brief Returns the unique timestamp value with the given tag associated with the context element.
/// @discussion Will trigger an assertion if there is more than one matching value.
- (nullable NSDate *)timestampItemValueForTag:(XMPPMessageContextTimestampItemTag)tag
NS_SWIFT_NAME(timestampItemValue(for:));

@end

NS_ASSUME_NONNULL_END
