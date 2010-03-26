#import <Foundation/Foundation.h>
#import "MulticastDelegate.h"

#if TARGET_OS_IPHONE
  #import "DDXML.h"
#endif

@class XMPPIQ;
@class XMPPJID;
@class XMPPStream;
@protocol XMPPCapabilitiesStorage;
@protocol XMPPCapabilitiesDelegate;


@interface XMPPCapabilities : NSObject
{
	XMPPStream *xmppStream;
	id <XMPPCapabilitiesStorage> xmppCapabilitiesStorage;
	
	MulticastDelegate <XMPPCapabilitiesDelegate> *multicastDelegate;
	
	NSMutableSet *discoRequestJidSet;
	NSMutableDictionary *discoRequestHashDict;
	NSMutableDictionary *discoTimerJidDict;
	
	BOOL autoFetchHashedCapabilities;
	BOOL autoFetchNonHashedCapabilities;
	
	NSTimeInterval capabilitiesRequestTimeout;
	
	NSMutableSet *timers;
}

- (id)initWithStream:(XMPPStream *)xmppStream capabilitiesStorage:(id <XMPPCapabilitiesStorage>)storage;

@property (nonatomic, readonly) XMPPStream *xmppStream;
@property (nonatomic, readonly) id <XMPPCapabilitiesStorage> xmppCapabilitiesStorage;

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
@property (nonatomic, assign) BOOL autoFetchHashedCapabilities;

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
@property (nonatomic, assign) BOOL autoFetchNonHashedCapabilities;

/**
 * Standard multicast delegate pattern.
 * 
 * Modules that wish to advertise their features (via disco response or within presence via XEP-0115)
 * should plug into this module and implement the xmppCapabilities:willSendMyCapabilities: delegate method.
**/

- (void)addDelegate:(id)delegate;
- (void)removeDelegate:(id)delegate;

/**
 * Manually fetch the capabilities for the given jid.
 * 
 * The jid must be a full jid (includes resource).
 * If there is an existing disco request associated with the current jid, this method does nothing.
 * 
 * When the capabilities are received, the xmppCapabilities:didDiscoverCapabilities: delegate method is invoked.
**/
- (void)fetchCapabilitiesForJID:(XMPPJID *)jid;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol XMPPCapabilitiesStorage <NSObject>
@required

@property (nonatomic, assign) XMPPCapabilities *parent;

// 
// 
// -- PUBLIC METHODS --
// 
// 

/**
 * Returns whether or not we know the capabilities for a given jid.
 * 
 * The jid may or may not be associated with a capabilities hash.
**/
- (BOOL)areCapabilitiesKnownForJID:(XMPPJID *)jid;

/**
 * Returns the capabilities for the given jid.
**/
- (XMPPIQ *)capabilitiesForJID:(XMPPJID *)jid;

/**
 * Returns the capabilities for the given jid.
 * The given jid must be a full jid (must contain a resource).
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
**/
- (XMPPIQ *)capabilitiesForJID:(XMPPJID *)jid ext:(NSString **)extPtr;

// 
// 
// -- PRIVATE METHODS --
// 
// These methods are designed to be used only by the XMPPCapabilities class.
// 
// 

/**
 * Sets metadata for the given jid.
 * 
 * This method should return:
 * - YES if the capabilities for the given jid are known.
 * - NO if the capabilities for the given jid are NOT known.
 * 
 * Note: If the hash and algorithm are given, and an associated set of capabilities matches the hash/algorithm,
 * this method should link the jid to the capabilities and return YES.
**/
- (BOOL)setCapabilitiesNode:(NSString *)node
                        ver:(NSString *)ver
                        ext:(NSString *)ext
                       hash:(NSString *)hash
                  algorithm:(NSString *)hashAlg
                     forJID:(XMPPJID *)jid;

/**
 * Fetches the associated capabilities hash for a given jid.
 * 
 * If the jid is not associated with a capabilities hash, this method should return NO.
 * Otherwise it should return YES, and set the corresponding variables.
**/
- (BOOL)getCapabilitiesHash:(NSString **)hashPtr algorithm:(NSString **)hashAlgPtr forJID:(XMPPJID *)jid;

/**
 * Clears any associated hash from a jid.
 * If the jid is linked to a set of capabilities, it should be unlinked.
**/
- (void)clearCapabilitiesHashAndAlgorithmForJID:(XMPPJID *)jid;

/**
 * Combination of areCapabilitiesKnown: and getCapabilitiesHash:algorithm:forJID: methods.
 * 
 * If the capabilities are known, the areCapabilitiesKnown boolean should be set to YES.
 * If jid is associated with a hash, the isHashKnown boolean should eb set to YES,
 * and the hash and hashAlg variables should be filled out.
**/
- (void)getCapabilitiesKnown:(BOOL *)areCapabilitiesKnownPtr
					  failed:(BOOL *)haveFailedFetchingBeforePtr
                        node:(NSString **)nodePtr
                         ver:(NSString **)verPtr
                         ext:(NSString **)extPtr
                        hash:(NSString **)hashPtr
                   algorithm:(NSString **)hashAlgPtr
                      forJID:(XMPPJID *)jid;

/**
 * Sets the capabilities associated with a given hash.
 * 
 * Since the capabilities are linked to a hash, these capabilities (and associated hash)
 * may be persisted to disk and/or persisted between multiple sessions/streams.
 * 
 * It is the responsibility of the storage implementation to link the
 * associated jids with this hash to the given set of capabilities.
 * 
 * Implementation Note:
 * 
 * If we receive multiple simultaneous presence elements from
 * multiple jids all broadcasting the same capabilities hash:
 * 
 * - The setCapabilitiesHash:algorithm:forJID: will be invoked for each jid.
 * - A single disco request will be sent to one of the jids.
 * - When the response comes back, the setCapabilities:forHash:algorithm: method will be invoked.
 * 
 * The setCapabilities:forJID: method will NOT be invoked for each corresponding jid.
 * This is by design to allow the storage implementation to optimize itself.
**/
- (void)setCapabilities:(XMPPIQ *)iq forHash:(NSString *)hash algorithm:(NSString *)hashAlg;

/**
 * Sets the capabilities for a given jid.
 * 
 * The jid is guaranteed NOT to be associated with a capabilities hash.
 * 
 * Since the capabilities are NOT linked to a hash,
 * these capabilities should not be persisted between multiple sessions/streams.
**/
- (void)setCapabilities:(XMPPIQ *)iq forJID:(XMPPJID *)jid;

/**
 * Marks the disco fetch request as failed so we know not to bother trying again.
**/
- (void)setCapabilitiesFetchFailedForJID:(XMPPJID *)jid;

/**
 * Clear non-persistent capabilities.
 * That is, capabilities that are not associated with a hash.
 * 
 * The clearAllNonPersistentCapabilities method is called when we go unavailable or offline.
 * The clearNonPersistentCapabilitiesForJID method is called when the given jid goes unavailable.
 * 
 * These methods should also clear any metadata such as node, ver, ext, hash and algorithm.
**/
- (void)clearAllNonPersistentCapabilities;
- (void)clearNonPersistentCapabilitiesForJID:(XMPPJID *)jid;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol XMPPCapabilitiesDelegate
@optional

/**
 * Use this delegate method to add specific capabilities.
 * This method may be invoked prior to sending a disco response, or prior to sending a presence element.
**/
- (void)xmppCapabilities:(XMPPCapabilities *)sender willSendMyCapabilities:(NSXMLElement *)query;

/**
 * Invoked when capabilities have been discovered for an available JID.
**/
- (void)xmppCapabilities:(XMPPCapabilities *)sender didDiscoverCapabilities:(XMPPIQ *)caps forJID:(XMPPJID *)jid;

@end
