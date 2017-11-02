#import "XMPPMessageCoreDataStorage.h"
#import "XMPPMessageCoreDataStorageObject.h"

NS_ASSUME_NONNULL_BEGIN

@interface XMPPMessageCoreDataStorageTransaction (XEP_0066)

/// @brief Registers XEP-0066 out of band resource information for the received message.
/// @discussion It is assumed that the provided @c XMPPMessage contains the relevant information. This method does not store core XMPP message properties.
- (void)registerOutOfBandResourceForReceivedMessage:(XMPPMessage *)message;

@end

@interface XMPPMessageCoreDataStorageObject (XEP_0066)

/// @brief Returns the internal ID of the XEP-0066 resource associated with the message.
/// @discussion The internal resource ID can be used as a reference to some auxiliary local storage (e.g. transferred files repository)
- (nullable NSString *)outOfBandResourceInternalID;

/// Returns the URI string identifying the XEP-0066 resource associated with the message.
- (nullable NSString *)outOfBandResourceURIString;

/// Returns the human-readable description of the XEP-0066 resource associated with the message.
- (nullable NSString *)outOfBandResourceDescription;

/**
 Associates the message storage object with a XEP-0066 resource with the given internal ID and an optional description.
 
 Each message storage object can only have a resource assigned once, subsequent attempts will trigger an assertion.
 
 @see setAssignedOutOfBandResourceURIString:
 */
- (void)assignOutOfBandResourceWithInternalID:(NSString *)internalID description:(nullable NSString *)resourceDescription;

/**
 Provides a resource URI to the message storage object with an associated XEP-0066 resource.
 
 An assertion will be triggered if no resource is associated with the message yet.
 
 The reason why assigning the resource and setting the URI use separate methods is that preparing an outgoing XEP-0066 message
 is often an asynchronous 2-step process, i.e. the URI may not be immediately available.
 
 @see assignOutOfBandResourceWithInternalID:description:
 */
- (void)setAssignedOutOfBandResourceURIString:(NSString *)resourceURIString;

@end

NS_ASSUME_NONNULL_END
