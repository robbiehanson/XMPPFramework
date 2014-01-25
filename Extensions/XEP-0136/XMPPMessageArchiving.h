#import <Foundation/Foundation.h>
#import "XMPP.h"

#define _XMPP_MESSAGE_ARCHIVING_H

@protocol XMPPMessageArchivingStorage;

/**
 * This class provides support for storing message history.
 * The functionality is formalized in XEP-0136.
**/
@interface XMPPMessageArchiving : XMPPModule
{
  @protected
	
	__strong id <XMPPMessageArchivingStorage> xmppMessageArchivingStorage;
	
  @private
	
	BOOL clientSideMessageArchivingOnly;
	NSXMLElement *preferences;
}

- (id)initWithMessageArchivingStorage:(id <XMPPMessageArchivingStorage>)storage;
- (id)initWithMessageArchivingStorage:(id <XMPPMessageArchivingStorage>)storage dispatchQueue:(dispatch_queue_t)queue;

@property (readonly, strong) id <XMPPMessageArchivingStorage> xmppMessageArchivingStorage;

/**
 * XEP-0136 Message Archiving outlines a complex protocol for:
 * 
 *  - archiving messages on the xmpp server
 *  - allowing the client to sync it's client-side cache with the server side archive
 *  - allowing the client to configure archiving preferences (default, per contact, etc)
 * 
 * There are times when this complication isn't necessary or possible.
 * E.g. the server doesn't support the message archiving protocol.
 * 
 * In this case you can simply set clientSideMessageArchivingOnly to YES,
 * and this instance won't bother with any of the server protocol stuff.
 * It will simply arhive outgoing and incoming messages.
 * 
 * Note: Even when clientSideMessageArchivingOnly is YES,
 *       you can still take advantage of the preference methods to configure various options,
 *       such as how long to store messages, prefs for individual contacts, etc.
**/
@property (readwrite, assign) BOOL clientSideMessageArchivingOnly;

/**
 * 
**/
@property (readwrite, copy) NSXMLElement *preferences;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol XMPPMessageArchivingStorage <NSObject>
@required

// 
// 
// -- PUBLIC METHODS --
// 
// There are no public methods required by this protocol.
// 
// Each individual roster storage class will provide a proper way to access/enumerate the
// users/resources according to the underlying storage mechanism.
// 


// 
// 
// -- PRIVATE METHODS --
// 
// These methods are designed to be used ONLY by the XMPPMessageArchiving class.
// 
// 

/**
 * Configures the storage class, passing its parent and parent's dispatch queue.
 * 
 * This method is called by the init method of the XMPPMessageArchiving class.
 * This method is designed to inform the storage class of its parent
 * and of the dispatch queue the parent will be operating on.
 * 
 * The storage class may choose to operate on the same queue as its parent,
 * or it may operate on its own internal dispatch queue.
 * 
 * This method should return YES if it was configured properly.
 * If a storage class is designed to be used with a single parent at a time, this method may return NO.
 * The XMPPMessageArchiving class is configured to ignore the passed
 * storage class in its init method if this method returns NO.
**/
- (BOOL)configureWithParent:(XMPPMessageArchiving *)aParent queue:(dispatch_queue_t)queue;

/**
 * 
**/
- (void)archiveMessage:(XMPPMessage *)message outgoing:(BOOL)isOutgoing xmppStream:(XMPPStream *)stream;

@optional

/**
 * The storage class may optionally persistently store the client preferences.
**/
- (void)setPreferences:(NSXMLElement *)prefs forUser:(XMPPJID *)bareUserJid;

/**
 * The storage class may optionally persistently store the client preferences.
 * This method is then used to fetch previously known preferences when the client first connects to the xmpp server.
**/
- (NSXMLElement *)preferencesForUser:(XMPPJID *)bareUserJid;

@end
