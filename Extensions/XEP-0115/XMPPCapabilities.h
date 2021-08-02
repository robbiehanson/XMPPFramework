#import <Foundation/Foundation.h>
#import "XMPP.h"

#define _XMPP_CAPABILITIES_H

@protocol XMPPCapabilitiesStorage;
@class GCDTimerWrapper;

/**
 * This class provides support for capabilities discovery.
 * 
 * It collects our capabilities and publishes them according to the XEP by:
 * - Injecting the <c/> element into outgoing presence stanzas
 * - Responding to incoming disco#info queries
 * 
 * It also collects the capabilities of available resources,
 * provides a mechanism to persistently store XEP-0115 hased caps,
 * and makes available a simple API to query (disco#info) a resource or server.
**/
NS_ASSUME_NONNULL_BEGIN
@interface XMPPCapabilities : XMPPModule
{
	__strong id <XMPPCapabilitiesStorage> xmppCapabilitiesStorage;
    
    NSString *myCapabilitiesNode;
	
	NSXMLElement *myCapabilitiesQuery; // Full list of capabilites <query/>
	NSXMLElement *myCapabilitiesC;     // Hashed element <c/>
	BOOL collectingMyCapabilities;
	
	NSMutableSet *discoRequestJidSet;
	NSMutableDictionary *discoRequestHashDict;
	NSMutableDictionary<XMPPJID*,GCDTimerWrapper*> *discoTimerJidDict;
	
	BOOL autoFetchHashedCapabilities;
	BOOL autoFetchNonHashedCapabilities;
	BOOL autoFetchMyServerCapabilities;
	
	NSTimeInterval capabilitiesRequestTimeout;
	
	NSMutableSet *timers;
}

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithDispatchQueue:(nullable dispatch_queue_t)queue NS_UNAVAILABLE;

- (instancetype)initWithCapabilitiesStorage:(id <XMPPCapabilitiesStorage>)storage;
- (instancetype)initWithCapabilitiesStorage:(id <XMPPCapabilitiesStorage>)storage dispatchQueue:(nullable dispatch_queue_t)queue NS_DESIGNATED_INITIALIZER;

@property (nonatomic, strong, readonly) id <XMPPCapabilitiesStorage> xmppCapabilitiesStorage;

/**
 * Defines the node attribute in a <c/> element qualified by the 'http://jabber.org/protocol/caps' namespace.
 *
 * It is RECOMMENDED for the value of the 'node' attribute to be an HTTP URL
 * at which a user could find further information about the software product, 
 * such as "http://github.com/robbiehanson/XMPPFramework"
 *
 * This MUST NOT be nil
 *
 * The default value is http://github.com/robbiehanson/XMPPFramework
**/

@property (nonatomic, copy) NSString *myCapabilitiesNode;

/**
 * Defines fetching behavior for entities using the XEP-0115 standard.
 * 
 * XEP-0115 defines a technique for hashing capabilities (disco info responses),
 * and broadcasting them within a presence element.
 * Due to the standardized hashing technique, capabilities associated with a hash may be persisted indefinitely.
 * 
 * The end result is that capabilities need to be fetched less often
 * since they are already known due to the caching of responses.
 * 
 * The default value is YES.
**/
@property (assign) BOOL autoFetchHashedCapabilities;

/**
 * Defines fetching behavior for entities NOT using the XEP-0115 standard.
 * 
 * Because the capabilities are not associated with a standardized hash,
 * it is not possible to cache the capabilities between sessions.
 * 
 * The default value is NO.
 * 
 * It is recommended you leave this value set to NO unless you
 * know that you'll need the capabilities of every resource,
 * and that fetching of the capabilities cannot be delayed.
 * 
 * You may always fetch the capabilities (if/when needed) via the fetchCapabilitiesForJID method.
**/
@property (assign) BOOL autoFetchNonHashedCapabilities;

/**
 * Auto fetch the capabilities of the server upon authentication.
 * This uses the non hashed approach outlined in XEP-0030: Service Discovery.
 *
 * The default value is NO.
**/

@property (assign) BOOL autoFetchMyServerCapabilities;

/**
 * Manually fetch the capabilities for the given jid.
 * 
 * The jid must be a full jid (user@domain/resource) or a domain JID (domain without user or resource).
 * You would pass a full jid if you wanted to know the capabilities of a particular user's resource.
 * You would pass a domain jid if you wanted to know the capabilities of a particular server.
 * 
 * If there is an existing disco request associated with the given jid, this method does nothing.
 * 
 * When the capabilities are received,
 * the xmppCapabilities:didDiscoverCapabilities:forJID: delegate method is invoked.
**/
- (void)fetchCapabilitiesForJID:(XMPPJID *)jid;

/**
 * This module automatically collects my capabilities.
 * See the xmppCapabilities:collectingMyCapabilities: delegate method.
 * 
 * The design of XEP-115 is such that capabilites are expected to remain rather static.
 * However, if the capabilities change, this method may be used to perform a manual update.
**/
- (void)recollectMyCapabilities;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol XMPPCapabilitiesStorage <NSObject>
@required

// 
// 
// -- PUBLIC METHODS --
// 
// 

/**
 * Returns whether or not we know the capabilities for a given jid.
 * 
 * The stream parameter is optional.
 * If given, the jid must have been registered via the given stream.
 * Otherwise it will match the given jid from any stream this storage instance is managing.
**/
- (BOOL)areCapabilitiesKnownForJID:(nullable XMPPJID *)jid xmppStream:(nullable XMPPStream *)stream;

/**
 * Returns the capabilities for the given jid.
 * The returned element is the <query/> element response to a disco#info request.
 * 
 * The stream parameter is optional.
 * If given, the jid must have been registered via the given stream.
 * Otherwise it will match the given jid from any stream this storage instance is managing.
**/
- (nullable NSXMLElement *)capabilitiesForJID:(nullable XMPPJID *)jid xmppStream:(nullable XMPPStream *)stream;

/**
 * Returns the capabilities for the given jid.
 * The returned element is the <query/> element response to a disco#info request.
 * 
 * The given jid should be a full jid (user@domain/resource) or a domin JID (domain without user or resource).
 * 
 * If the jid has broadcast capabilities via the legacy format of XEP-0115,
 * the extension list may optionally be retrieved via the ext parameter.
 * 
 * For example, the jid may send a presence element like:
 * 
 * <presence from="jid">
 *   <c node="imclient.com/caps" ver="1.2" ext="rdserver rdclient avcap"/>
 * </presence>
 * 
 * In the above example, the ext string would be set to "rdserver rdclient avcap".
 * 
 * You may pass nil for extPtr if you don't care about the legacy attributes,
 * or you could simply use the capabilitiesForJID: method above.
 * 
 * The stream parameter is optional.
 * If given, the jid must have been registered via the given stream.
 * Otherwise it will match the given jid from any stream this storage instance is managing.
**/
- (nullable NSXMLElement *)capabilitiesForJID:(nullable XMPPJID *)jid ext:(NSString * _Nullable * _Nullable)extPtr xmppStream:(nullable XMPPStream *)stream;

// 
// 
// -- PRIVATE METHODS --
// 
// These methods are designed to be used ONLY by the XMPPCapabilities class.
// 
// 

/**
 * Configures the capabilities storage class, passing it's parent and parent's dispatch queue.
 * 
 * This method is called by the init methods of the XMPPCapabilities class.
 * This method is designed to inform the storage class of it's parent
 * and of the dispatch queue the parent will be operating on.
 * 
 * A storage class may choose to operate on the same queue as it's parent,
 * as the majority of the time it will be getting called by the parent.
 * If both are operating on the same queue, the combination may run faster.
 * 
 * Some storage classes support multiple xmppStreams,
 * and may choose to operate on their own internal queue.
 * 
 * This method should return YES if it was configured properly.
 * It should return NO only if configuration failed.
 * For example, a storage class designed to be used only with a single xmppStream is being added to a second stream.
 * The XMPPCapabilites class is configured to ignore the passed
 * storage class in it's init method if this method returns NO.
**/
- (BOOL)configureWithParent:(XMPPCapabilities *)aParent queue:(dispatch_queue_t)queue;

/**
 * Sets metadata for the given jid.
 * 
 * This method should return:
 * - YES if the capabilities for the given jid are known.
 * - NO if the capabilities for the given jid are NOT known.
 * 
 * If the hash and algorithm are given, and an associated set of capabilities matches the hash/algorithm,
 * this method should link the jid to the capabilities and return YES.
 * 
 * If the linked set of capabilities was not previously linked to the jid,
 * the newCapabilities parameter shoud be filled out.
 * 
 * This method may be called multiple times for a given jid with the same information.
 * If this method sets the newCapabilitiesPtr parameter,
 * the XMPPCapabilities module will invoke the xmppCapabilities:didDiscoverCapabilities:forJID: delegate method.
 * This delegate method is designed to be invoked only when the capabilities for the given JID have changed.
 * That is, the capabilities for the jid have been discovered for the first time (jid just signed in)
 * or the capabilities for the given jid have changed (jid broadcast new capabilities).
**/
- (BOOL)setCapabilitiesNode:(NSString *)node
                        ver:(NSString *)ver
                        ext:(nullable NSString *)ext
                       hash:(nullable NSString *)hash
                  algorithm:(nullable NSString *)hashAlg
                     forJID:(XMPPJID *)jid
                 xmppStream:(XMPPStream *)stream
      andGetNewCapabilities:(NSXMLElement *_Nullable*_Nullable)newCapabilitiesPtr;

/**
 * Fetches the associated capabilities hash for a given jid.
 * 
 * If the jid is not associated with a capabilities hash, this method should return NO.
 * Otherwise it should return YES, and set the corresponding variables.
**/
- (BOOL)getCapabilitiesHash:(NSString *_Nullable*_Nullable)hashPtr
                  algorithm:(NSString *_Nullable*_Nullable)hashAlgPtr
                     forJID:(XMPPJID *)jid
                 xmppStream:(XMPPStream *)stream;

/**
 * Clears any associated hash from a jid.
 * If the jid is linked to a set of capabilities, it should be unlinked.
 * 
 * This method should not clear the actual capabilities information itself.
 * It should simply unlink the connection between the jid and the capabilities.
**/
- (void)clearCapabilitiesHashAndAlgorithmForJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream;

/**
 * Gets the metadata for the given jid.
 * 
 * If the capabilities are known, the areCapabilitiesKnown boolean should be set to YES.
**/
- (void)getCapabilitiesKnown:(BOOL * _Nullable )areCapabilitiesKnownPtr
					  failed:(BOOL * _Nullable)haveFailedFetchingBeforePtr
                        node:(NSString *_Nullable*_Nullable)nodePtr
                         ver:(NSString *_Nullable*_Nullable)verPtr
                         ext:(NSString *_Nullable*_Nullable)extPtr
                        hash:(NSString *_Nullable*_Nullable)hashPtr
                   algorithm:(NSString *_Nullable*_Nullable)hashAlgPtr
                      forJID:(XMPPJID *)jid
                  xmppStream:(XMPPStream *)stream;

/**
 * Sets the capabilities associated with a given hash.
 * 
 * Since the capabilities are linked to a hash, these capabilities (and associated hash)
 * should be persisted to disk and persisted between multiple sessions/streams.
 * 
 * It is the responsibility of the storage implementation to link the
 * associated jids (those with the given hash) to the given set of capabilities.
 * 
 * Implementation Note:
 * 
 * If we receive multiple simultaneous presence elements from
 * multiple jids all broadcasting the same capabilities hash:
 * 
 * - A single disco request will be sent to one of the jids.
 * - When the response comes back, the setCapabilities:forHash:algorithm: method will be invoked.
 * 
 * The setCapabilities:forJID: method will NOT be invoked for each corresponding jid.
 * This is by design to allow the storage implementation to optimize itself.
**/
- (void)setCapabilities:(NSXMLElement *)caps forHash:(NSString *)hash algorithm:(NSString *)hashAlg;

/**
 * Sets the capabilities for a given jid.
 * 
 * The jid is guaranteed NOT to be associated with a capabilities hash.
 * 
 * Since the capabilities are NOT linked to a hash,
 * these capabilities should not be persisted between multiple sessions/streams.
 * See the various clear methods below.
**/
- (void)setCapabilities:(NSXMLElement *)caps forJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream;

/**
 * Marks the disco fetch request as failed so we know not to bother trying again.
 * 
 * This is temporary metadata associated with the jid.
 * It should be cleared when we go unavailable or offline, or if the given jid goes unavailable.
 * See the various clear methods below.
**/
- (void)setCapabilitiesFetchFailedForJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream;

/**
 * This method is called when we go unavailable or offline.
 * 
 * This method should clear all metadata (node, ver, ext, hash, algorithm, failed) from all jids in the roster.
 * All jids should be unlinked from associated capabilities.
 * 
 * If the associated capabilities are persistent, they should not be cleared.
 * That is, if the associated capabilities are associated with a hash, they should be persisted.
 * 
 * Non persistent capabilities (those not associated with a hash)
 * should be cleared at this point as they will no longer be linked to any users.
**/
- (void)clearAllNonPersistentCapabilitiesForXMPPStream:(XMPPStream *)stream;

/**
 * This method is called when the given jid goes unavailable.
 * 
 * This method should clear all metadata (node, ver, ext, hash ,algorithm, failed) from the given jid.
 * The jid should be unlinked from associated capabilities.
 * 
 * If the associated capabilities are persistent, they should not be cleared.
 * That is, if the associated capabilities are associated with a hash, they should be persisted.
 * 
 * Non persistent capabilities (those not associated with a hash) should be cleared.
**/
- (void)clearNonPersistentCapabilitiesForJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol XMPPCapabilitiesDelegate
@optional

/**
 * Use this delegate method to add specific capabilities.
 * This method in invoked automatically when the stream is connected for the first time,
 * or if the module detects an outgoing presence element and my capabilities haven't been collected yet
 * 
 * The design of XEP-115 is such that capabilites are expected to remain rather static.
 * However, if the capabilities change, the recollectMyCapabilities method may be used to perform a manual update.
**/
- (void)xmppCapabilities:(XMPPCapabilities *)sender collectingMyCapabilities:(NSXMLElement *)query;


/**
 * Use this delegate method to return the feature you want to have in your capabilities e.g. @[@"urn:xmpp:archive"]
 * Duplicate features are automatically discarded
 * For more control over your capablities use xmppCapabilities:collectingMyCapabilities:
**/
- (NSArray<NSString*>*)myFeaturesForXMPPCapabilities:(XMPPCapabilities *)sender;

/**
 * Invoked when capabilities have been discovered for an available JID.
 * 
 * The caps element is the <query/> element response to a disco#info request.
**/
- (void)xmppCapabilities:(XMPPCapabilities *)sender didDiscoverCapabilities:(NSXMLElement *)caps forJID:(XMPPJID *)jid;

@end

NS_ASSUME_NONNULL_END
