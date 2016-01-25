#import <Foundation/Foundation.h>
#import "XMPPModule.h"

@import KissXML;

#define _XMPP_BLOCKING_H

@class XMPPIQ;

extern NSString *const XMPPBlockingErrorDomain;

typedef enum XMPPBlockingErrorCode
{
	XMPPBlockingQueryTimeout,  // No response from server
	XMPPBlockingDisconnect,    // XMPP disconnection
	
} XMPPBlockingErrorCode;

@interface XMPPBlocking : XMPPModule
{
    BOOL autoRetrieveBlockingListItems;
    BOOL autoClearBlockingListInfo;
    
    NSMutableDictionary *blockingDict;
    
    NSMutableDictionary *pendingQueries;
}

/**
 * Whether or not the module should automatically retrieve the blocking list rules.
 * If this property is enabled, then the rules for each blocking list are automatically fetched.
 *
 * In other words, if the blocking list names are fetched (either automatically, or via retrieveListItems),
 * then the module will automatically fetch the associated rules.
 *
 * The default value is YES.
 **/
@property (readwrite, assign) BOOL autoRetrieveBlockingListItems;

/**
 * Whether the module should automatically clear the blocking list info when the client disconnects.
 *
 * As per the XEP, if there are multiple resources signed in for the user,
 * and one resource makes changes to a blocking list, all other resources are "pushed" a notification.
 * However, if our client is disconnected when another resource makes the changes,
 * then the only way we can find out about the changes are to redownload the blocking lists.
 *
 * It is recommended to clear the blocking list to assure we have the correct info.
 * However, there may be specific situations in which an xmpp client can be sure the blocking list won't change.
 *
 * The default value is YES.
 **/
@property (readwrite, assign) BOOL autoClearBlockingListInfo;

/**
 * Blocking dict
 */
@property (readonly, strong) NSMutableDictionary *blockingDict;

/**
 * Manual fetch of list names and rules, and manual control over when to clear stored info.
 **/
- (void)retrieveBlockingListItems;
- (void)clearBlockingListInfo;

/**
 * Returns the blocking list.
 *
 * The result is an array or blocking items (NSXMLElement's).
 **/
- (NSArray*)blockingList;

/**
 * Block JID.
 */
- (void)blockJID:(XMPPJID*)xmppJID;

/**
 * Unblock JID.
 */
- (void)unblockJID:(XMPPJID*)xmppJID;

/**
 * Return whether a jid is in blocking list or not.
 */
- (BOOL)containsJID:(XMPPJID*)xmppJID;

/**
 * Unblock all.
 */
- (void)unblockAll;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol XMPPBlockingDelegate
@optional

/**
 * The following delegate methods correspond almost exactly with the action methods of the class.
 * There are a few possible ways in which an action could fail:
 *
 * 1. We receive an error response from the server.
 * 2. We receive no response from the server, and the query times out.
 * 3. We get disconnected before we receive the response.
 *
 * In case number 1, the error will be an XMPPIQ of type='error'.
 *
 * In case number 2 or 3, the error will be an NSError
 * with domain=XMPPPrivacyErrorDomain and code from the XMPPBlockingErrorCode enumeration.
 **/

- (void)xmppBlocking:(XMPPBlocking *)sender didReceivedBlockingList:(NSArray*)blockingList;
- (void)xmppBlocking:(XMPPBlocking *)sender didNotReceivedBlockingListDueToError:(id)error;

- (void)xmppBlocking:(XMPPBlocking *)sender didReceivePushWithBlockingList:(NSString *)name;

- (void)xmppBlocking:(XMPPBlocking *)sender didBlockJID:(XMPPJID*)xmppJID;
- (void)xmppBlocking:(XMPPBlocking *)sender didNotBlockJID:(XMPPJID*)xmppJID error:(id)error;

- (void)xmppBlocking:(XMPPBlocking *)sender didUnblockJID:(XMPPJID*)xmppJID;
- (void)xmppBlocking:(XMPPBlocking *)sender didNotUnblockJID:(XMPPJID*)xmppJID error:(id)error;

- (void)xmppBlocking:(XMPPBlocking *)sender didUnblockAllWithError:(id)error;
- (void)xmppBlocking:(XMPPBlocking *)sender didNotUnblockAllDueToError:(id)error;

@end