//
//  OMEMOModule.h
//  XMPPFramework
//
//  Created by Chris Ballinger on 4/21/16.
//
//  XEP-0384: OMEMO Encryption
//  https://xmpp.org/extensions/xep-0384.html
//
//  This specification defines a protocol for end-to-end encryption
//  in one-on-one chats that may have multiple clients per account.
//
//  To use this module, you must also hook up a library compatible with
//  the Double Ratchet algorithm [1] and X3DH [2]. You can use the
//  SignalProtocol-ObjC [3] library but beware that it is GPL so cannot
//  be used in closed source apps.
//
//  1. https://en.wikipedia.org/wiki/Double_Ratchet_Algorithm
//  2. https://whispersystems.org/docs/specifications/x3dh/
//  3. https://github.com/ChatSecure/SignalProtocol-ObjC
//

#import <Foundation/Foundation.h>
#import "XMPP.h"
#import "XMPPCapabilities.h"
#import "OMEMOBundle.h"
#import "OMEMOKeyData.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, OMEMOModuleNamespace) {
    /** Uses "eu.siacs.conversations.axolotl" namespace and compatible with the latest Conversations and ChatSecure versions as of Feb 8, 2017.  */
    OMEMOModuleNamespaceConversationsLegacy,
    /** Uses "urn:xmpp:omemo:0" namespace. XEP is still experimental. Do not use in production yet as it may change! See https://xmpp.org/extensions/xep-0384.html */
    OMEMOModuleNamespaceOMEMO
};

@protocol OMEMOStorageDelegate;

/**
 *  XEP-0384 OMEMO Encryption
 *  http://xmpp.org/extensions/xep-0384.html
 *
 *  This specification defines a protocol for end-to-end encryption in one-on-one chats that may have multiple clients per account.
 */
@interface OMEMOModule : XMPPModule <XMPPStreamDelegate, XMPPCapabilitiesDelegate>

@property (nonatomic, readonly) OMEMOModuleNamespace xmlNamespace;
@property (nonatomic, strong, readonly) id<OMEMOStorageDelegate> omemoStorage;

#pragma mark Init

- (instancetype) initWithOMEMOStorage:(id<OMEMOStorageDelegate>)omemoStorage xmlNamespace:(OMEMOModuleNamespace)xmlNamespace;
- (instancetype) initWithOMEMOStorage:(id<OMEMOStorageDelegate>)omemoStorage xmlNamespace:(OMEMOModuleNamespace)xmlNamespace dispatchQueue:(nullable dispatch_queue_t)queue NS_DESIGNATED_INITIALIZER;

/** Not available, use designated initializer */
- (instancetype) init NS_UNAVAILABLE;
/** Not available, use designated initializer */
- (instancetype) initWithDispatchQueue:(nullable dispatch_queue_t)queue NS_UNAVAILABLE;

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

/** For manually fetching deviceIds list. This should be handled automatically by PEP if you send a <presence> update on login. */
- (void) fetchDeviceIdsForJID:(XMPPJID*)jid
                    elementId:(nullable NSString*)elementId;

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
 * Remove a device from the remote XMPP server. Removes the bundle for each device. Fetches and removees the devices from the device list.
 * The callbacks for removing a bundle (either success or failure) do not prevent the device list from being updated.
 *
 * Callbacks include:
 * omemo:failedToRemoveDeviceIds:errorIq:elementId:
 * omemo:removedBundleId:responseIq:outgoingIq:elementId:
 * omemo:failedToRemoveBundleId:errorIq:outgoingIq:elementId:
 * omemo:deviceListUpdate:fromJID:incomingElement:
 *
 * @param deviceIds remote deviceids
 * @param elementId XMPP elementid. If nil a random UUID will be used.
 */
- (void) removeDeviceIds:(NSArray<NSNumber*>*)deviceIds
               elementId:(nullable NSString *)elementId;

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
- (void) sendKeyData:(NSArray<OMEMOKeyData*>*)keyData
                  iv:(NSData*)iv
               toJID:(XMPPJID*)toJID
             payload:(nullable NSData*)payload
           elementId:(nullable NSString*)elementId;

/** Returns an unsent OMEMO message to be modified or sent elsewhere. Beware this may block! */
- (nullable XMPPMessage*) messageForKeyData:(NSArray<OMEMOKeyData*>*)keyData
                                iv:(NSData*)iv
                             toJID:(XMPPJID*)toJID
                           payload:(nullable NSData*)payload
                         elementId:(nullable NSString*)elementId;

#pragma mark Namespace methods

+ (NSString*) xmlnsOMEMO:(OMEMOModuleNamespace)ns;
+ (NSString*) xmlnsOMEMODeviceList:(OMEMOModuleNamespace)ns;
+ (NSString*) xmlnsOMEMODeviceListNotify:(OMEMOModuleNamespace)ns;
+ (NSString*) xmlnsOMEMOBundles:(OMEMOModuleNamespace)ns;
+ (NSString*) xmlnsOMEMOBundles:(OMEMOModuleNamespace)ns deviceId:(uint32_t)deviceId;

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
 * Device removal failed. The element Id is not the true element id of the sent stanza. It's used to track against the elmeent Id passed in the remove device method.
 */
- (void)omemo:(OMEMOModule*)omemo
failedToRemoveDeviceIds:(NSArray<NSNumber*>*)deviceIds
      errorIq:(nullable XMPPIQ*)errorIq
   elementId:(nullable NSString *)elementId;


/**
 * In order to determine whether a given contact has devices that support OMEMO, the devicelist node in PEP is consulted. Devices MUST subscribe to 'urn:xmpp:omemo:0:devicelist' via PEP, so that they are informed whenever their contacts add a new device. They MUST cache the most up-to-date version of the devicelist.
 */
- (void)omemo:(OMEMOModule*)omemo deviceListUpdate:(NSArray<NSNumber*>*)deviceIds fromJID:(XMPPJID*)fromJID incomingElement:(XMPPElement*)incomingElement;

/** Failed to fetch deviceList */
- (void)omemo:(OMEMOModule*)omemo failedToFetchDeviceIdsForJID:(XMPPJID*)fromJID errorIq:(nullable XMPPIQ*)errorIq
   outgoingIq:(XMPPIQ*)outgoingIq;

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
- (void)omemo:(OMEMOModule*)omemo
failedToFetchBundleForDeviceId:(uint32_t)deviceId
      fromJID:(XMPPJID*)fromJID
      errorIq:(nullable XMPPIQ*)errorIq
   outgoingIq:(XMPPIQ*)outgoingIq;

/**
 * Incoming MessageElement payload, keyData, and IV. If no payload it's a KeyTransportElement
- (void)omemo:(OMEMOModule*)omemo
failedToSendKeyData:(NSArray<OMEMOKeyData*>*)keyData
           iv:(NSData*)iv
      toJID:(XMPPJID*)toJID
      payload:(nullable NSData*)payload
 errorMessage:(nullable XMPPMessage*)errorMessage
      outgoingMessage:(XMPPMessage*)outgoingMessage;
 */

/**
 * Incoming MessageElement payload, keyData, and IV. If no payload it's a KeyTransportElement */
- (void)omemo:(OMEMOModule*)omemo
receivedKeyData:(NSArray<OMEMOKeyData*>*)keyData
           iv:(NSData*)iv
senderDeviceId:(uint32_t)senderDeviceId
      fromJID:(XMPPJID*)fromJID
      payload:(nullable NSData*)payload
      message:(XMPPMessage*)message;


/** This is called when receiving a MAM or Carbons message */
- (void)omemo:(OMEMOModule*)omemo
receivedForwardedKeyData:(NSArray<OMEMOKeyData*>*)keyData
           iv:(NSData*)iv
senderDeviceId:(uint32_t)senderDeviceId
       forJID:(XMPPJID*)forJID
      payload:(nullable NSData*)payload
   isIncoming:(BOOL)isIncoming
      delayed:(nullable NSDate*)delayed
forwardedMessage:(XMPPMessage*)forwardedMessage
originalMessage:(XMPPMessage*)originalMessage;

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
