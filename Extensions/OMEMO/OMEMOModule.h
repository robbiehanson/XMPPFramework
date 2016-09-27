//
//  OMEMOModule.h
//  XMPPFramework
//
//  Created by Chris Ballinger on 4/21/16.
//
//

#import <Foundation/Foundation.h>
#import "XMPP.h"
#import "XMPPCapabilities.h"
#import "OMEMOBundle.h"

#define XMLNS_OMEMO @"urn:xmpp:omemo:0"
#define XMLNS_OMEMO_DEVICELIST @"urn:xmpp:omemo:0:devicelist"
#define XMLNS_OMEMO_DEVICELIST_NOTIFY @"urn:xmpp:omemo:0:devicelist+notify"
#define XMLNS_OMEMO_BUNDLES @"urn:xmpp:omemo:0:bundles"

NS_ASSUME_NONNULL_BEGIN

@protocol OMEMOStorageDelegate;

/**
 *  XEP-xxxx OMEMO Encryption
 *  https://conversations.im/xeps/multi-end.html
 *
 *  This specification defines a protocol for end-to-end encryption in one-on-one chats that may have multiple clients per account.
 */
@interface OMEMOModule : XMPPModule <XMPPStreamDelegate, XMPPCapabilitiesDelegate>

@property (nonatomic, strong, readonly) id<OMEMOStorageDelegate> omemoStorage;

#pragma mark Init

- (instancetype) initWithOMEMOStorage:(id<OMEMOStorageDelegate>)omemoStorage;
- (instancetype) initWithOMEMOStorage:(id<OMEMOStorageDelegate>)omemoStorage dispatchQueue:(nullable dispatch_queue_t)queue NS_DESIGNATED_INITIALIZER;

/** Not available, use designated initializer */
- (instancetype) init NS_UNAVAILABLE;
/** Not available, use designated initializer */
- (instancetype) initWithDispatchQueue:(dispatch_queue_t)queue NS_UNAVAILABLE;

#pragma mark Public methods

/** 
 * In order for other devices to be able to initiate a session with a given device, it first has to announce itself by adding its device ID to the devicelist PEP node.
 *
 * Devices MUST check that their own device ID is contained in the list whenever they receive a PEP update from their own account. If they have been removed, they MUST reannounce themselves.
 *
 * @param deviceIds The Device ID is a randomly generated integer between 1 and 2^31 - 1 wrapped in an NSNumber.
 * @param elementId XMPP element id. If nil a random UUID will be used.
 */
- (void) publishDeviceIds:(NSArray<NSNumber*>*)deviceIds
                elementId:(nullable NSString*)elementId;

/** For fetching. This should be handled automatically by PEP.
- (void) fetchDeviceIdsForJID:(XMPPJID*)jid;
*/

/**
 * A device MUST announce it's IdentityKey, a signed PreKey, and a list of PreKeys in a separate, per-device PEP node. The list SHOULD contain 100 PreKeys, but MUST contain no less than 20.
 * 
 * @param bundle your device bundle
 * @param elementId XMPP element id. If nil a random UUID will be used.
 */
- (void) publishBundle:(OMEMOBundle*)bundle
             elementId:(nullable NSString*)elementId;

/**
 *  Fetches device bundle for a remote JID.
 *
 * @param deviceId remote deviceId
 * @param jid remote JID
 * @param elementId XMPP element id. If nil a random UUID will be used.
 */
- (void) fetchBundleForDeviceId:(uint32_t)deviceId
                            jid:(XMPPJID*)jid
                      elementId:(nullable NSString*)elementId;

/**
 In order to send a chat message, its <body> first has to be encrypted. The client MUST use fresh, randomly generated key/IV pairs with AES-128 in Galois/Counter Mode (GCM). For each intended recipient device, i.e. both own devices as well as devices associated with the contact, this key is encrypted using the corresponding long-standing axolotl session. Each encrypted payload key is tagged with the recipient device's ID. This is all serialized into a MessageElement.
 
  The client may wish to transmit keying material to the contact. This first has to be generated. The client MUST generate a fresh, randomly generated key/IV pair. For each intended recipient device, i.e. both own devices as well as devices associated with the contact, this key is encrypted using the corresponding long-standing axolotl session. Each encrypted payload key is tagged with the recipient device's ID. This is all serialized into a KeyTransportElement, omitting the <payload> as follows:
 *
 * @param payload data encrypted with fresh AES-128 GCM key/iv pair. If nil this is equivalent to a KeyTransportElement.
 * @param jid recipient JID
 * @param keyData payload's AES key encrypted to each recipient deviceId's Axolotl session
 * @param iv the IV used for encryption of payload
 * @param elementId XMPP element id. If nil a random UUID will be used.
 */
- (void) sendKeyData:(NSDictionary<NSNumber*,NSData*>*)keyData
                  iv:(NSData*)iv
               toJID:(XMPPJID*)toJID
             payload:(nullable NSData*)payload
           elementId:(nullable NSString*)elementId;

@end

@protocol OMEMOModuleDelegate <NSObject>
@optional

/** Callback for when your device list is successfully published */
- (void)omemo:(OMEMOModule*)omemo
publishedDeviceIds:(NSArray<NSNumber*>*)deviceIds
   responseIq:(XMPPIQ*)responseIq
   outgoingIq:(XMPPIQ*)outgoingIq;

/** Callback for when your device list update fails. If errorIq is nil there was a timeout. */
- (void)omemo:(OMEMOModule*)omemo
failedToPublishDeviceIds:(NSArray<NSNumber*>*)deviceIds
      errorIq:(nullable XMPPIQ*)errorIq
   outgoingIq:(XMPPIQ*)outgoingIq;


/**
 * In order to determine whether a given contact has devices that support OMEMO, the devicelist node in PEP is consulted. Devices MUST subscribe to 'urn:xmpp:omemo:0:devicelist' via PEP, so that they are informed whenever their contacts add a new device. They MUST cache the most up-to-date version of the devicelist.
 */
- (void)omemo:(OMEMOModule*)omemo deviceListUpdate:(NSArray<NSNumber*>*)deviceIds fromJID:(XMPPJID*)fromJID message:(XMPPMessage*)message;

/** Callback for when your bundle is successfully published */
- (void)omemo:(OMEMOModule*)omemo
    publishedBundle:(OMEMOBundle*)bundle
    responseIq:(XMPPIQ*)responseIq
    outgoingIq:(XMPPIQ*)outgoingIq;

/** Callback when publishing your bundle fails */
- (void)omemo:(OMEMOModule*)omemo
failedToPublishBundle:(OMEMOBundle*)bundle
      errorIq:(nullable XMPPIQ*)errorIq
   outgoingIq:(XMPPIQ*)outgoingIq;

/**
 * Process the incoming OMEMO bundle somewhere in your application
 */
- (void)omemo:(OMEMOModule*)omemo
fetchedBundle:(OMEMOBundle*)bundle
      fromJID:(XMPPJID*)fromJID
   responseIq:(XMPPIQ*)responseIq
   outgoingIq:(XMPPIQ*)outgoingIq;

/** Bundle fetch failed */
- (void)omemo:(OMEMOBundle*)omemo
failedToFetchBundleForDeviceId:(uint32_t)deviceId
      fromJID:(XMPPJID*)fromJID
      errorIq:(nullable XMPPIQ*)errorIq
   outgoingIq:(XMPPIQ*)outgoingIq;

/**
 * Incoming MessageElement payload, keyData, and IV. If no payload it's a KeyTransportElement
- (void)omemo:(OMEMOModule*)omemo
failedToSendKeyData:(NSDictionary<NSNumber*,NSData*>*)keyData
           iv:(NSData*)iv
      toJID:(XMPPJID*)toJID
      payload:(nullable NSData*)payload
 errorMessage:(nullable XMPPMessage*)errorMessage
      outgoingMessage:(XMPPMessage*)outgoingMessage;
 */

/**
 * Incoming MessageElement payload, keyData, and IV. If no payload it's a KeyTransportElement */
- (void)omemo:(OMEMOModule*)omemo
receivedKeyData:(NSDictionary<NSNumber*,NSData*>*)keyData
           iv:(NSData*)iv
      fromJID:(XMPPJID*)fromJID
      payload:(nullable NSData*)payload
      message:(XMPPMessage*)message;

@end

@protocol OMEMOStorageDelegate <NSObject>
@required

/** Return YES if successful. Optionally store a reference to parent module and moduleQueue */
- (BOOL)configureWithParent:(OMEMOModule *)aParent queue:(dispatch_queue_t)queue;

/** Store new deviceIds for a bare JID */
- (void)storeDeviceIds:(NSArray<NSNumber*>*)deviceIds forJID:(XMPPJID*)jid;

/** Fetch all deviceIds for a given bare JID. Return empty array if not found. */
- (NSArray<NSNumber*>*)fetchDeviceIdsForJID:(XMPPJID*)jid;

/** This should return your fully populated bundle with >= 100 prekeys. Return nil if bundle is not found. */
- (nullable OMEMOBundle*)fetchMyBundle;

/** Return YES if SignalProtocol session has been established and is valid */
- (BOOL) isSessionValid:(XMPPJID*)jid deviceId:(uint32_t)deviceId;

@end
NS_ASSUME_NONNULL_END
