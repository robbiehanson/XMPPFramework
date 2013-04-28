#import <Foundation/Foundation.h>
#import "XMPPModule.h"

#if TARGET_OS_IPHONE
  #import "DDXML.h"
#endif

#define _XMPP_PRIVACY_H

@class XMPPIQ;

extern NSString *const XMPPPrivacyErrorDomain;

typedef enum XMPPPrivacyErrorCode
{
	XMPPPrivacyQueryTimeout,  // No response from server
	XMPPPrivacyDisconnect,    // XMPP disconnection
	
} XMPPPrivacyErrorCode;



@interface XMPPPrivacy : XMPPModule
{
	BOOL autoRetrievePrivacyListNames;
	BOOL autoRetrievePrivacyListItems;
	BOOL autoClearPrivacyListInfo;
	
	NSMutableDictionary *privacyDict;
	NSString *activeListName;
	NSString *defaultListName;
	
	NSMutableDictionary *pendingQueries;
}

/**
 * Whether or not the module should automatically retrieve the privacy list names.
 * If this property is enabled, then the list is automatically fetched when the client signs in.
 * 
 * The default value is YES.
**/
@property (readwrite, assign) BOOL autoRetrievePrivacyListNames;

/**
 * Whether or not the module should automatically retrieve the privacy list rules.
 * If this property is enabled, then the rules for each privacy list are automatically fetched.
 * 
 * In other words, if the privacy list names are fetched (either automatically, or via retrieveListNames),
 * then the module will automatically fetch the associated rules.
 * It will also update the set of rules if we receive a "privacy list push"
 * from the server that another resource has changed one of the privacy lists.
 * 
 * The default value is YES.
**/
@property (readwrite, assign) BOOL autoRetrievePrivacyListItems;

/**
 * Whether the module should automatically clear the privacy list info when the client disconnects.
 * 
 * As per the XEP, if there are multiple resources signed in for the user,
 * and one resource makes changes to a privacy list, all other resources are "pushed" a notification.
 * However, if our client is disconnected when another resource makes the changes,
 * then the only way we can find out about the changes are to redownload the privacy lists.
 * 
 * It is recommended to clear the privacy list to assure we have the correct info.
 * However, there may be specific situations in which an xmpp client can be sure the privacy list won't change.
 * 
 * The default value is YES.
**/
@property (readwrite, assign) BOOL autoClearPrivacyListInfo;

/**
 * Manual fetch of list names and rules, and manual control over when to clear stored info.
**/
- (void)retrieveListNames;
- (void)retrieveListWithName:(NSString *)privacyListName;
- (void)clearPrivacyListInfo;

/**
 * Returns the privacy list names.
 * This is an array of strings.
**/
- (NSArray *)listNames;

/**
 * Returns the privacy list rules/items for the given list name.
 * 
 * The result is an array or privacy items (NSXMLElement's).
 * The array is sorted according to order, where the item with the smallest 'order' is first in the array.
**/
- (NSArray *)listWithName:(NSString *)privacyListName;

/**
 * Returns information about the active list.
 * If there is no active list, the methods return nil.
 * 
 * The activeList method is a convenience method for [modPriv listWithName:[modPriv activeListName]]
**/
- (NSString *)activeListName;
- (NSArray *)activeList;

/**
 * Returns information about the default list.
 * If there is no default list, the methods return nil.
 * 
 * The defaultList method is a convenience method for [modPriv listWithName:[modPriv defaultListName]]
**/
- (NSString *)defaultListName;
- (NSArray *)defaultList;

/**
 * Changes the client's active privacy list to the list with the given name.
 * The privacy list name must match the name of an existing privacy list.
 * 
 * To decline the use of an active list simply pass nil to this method.
 * 
 * Once the server has acknowledged the change,
 * the delegate method xmppPrivacy:didSetActiveListName: will be invoked.
 * If the server is unable to process the change (e.g. invalid list name),
 * the delegate method xmppPrivacy:didNotSetActiveListName:error: will be invoked.
 * 
 * The methods activeListName and activeList will update after the server acknowledges the change.
**/
- (void)setActiveListName:(NSString *)privacyListName;

/**
 * Changes the client's default privacy list to the list with the given name.
 * The privacy list name must match the name of an existing privacy list.
 * 
 * To decline the use of a default list simply pass nil to this method.
 * 
 * Once the server has acknowledged the change,
 * the delegate method xmppPrivacy:didSetDefaultListName: will be invoked.
 * If the server is unable to process the change (e.g. invalid list name, in use by another resource),
 * the delegate method xmppPrivacy:didNotSetDefaultListName:error: will be invoked.
 * 
 * The methods defaultListName and defaultList will update after the server acknowledges the change.
**/
- (void)setDefaultListName:(NSString *)privacyListName;

/**
 * Adds/Edits/Removes a privacy list with the given name.
 * The given array should contain only privacy items (NSXMLElement's).
 * 
 * To remove a privacy list, invoke this method will a nil or empty items parameter.
**/
- (void)setListWithName:(NSString *)privacyListName items:(NSArray *)items;

/**
 * The following are convenience methods to create privacy item rules.
 * A quick refresher from the XEP-0016 documentation is provided below.
 * 
 * The 'type' attribute is OPTIONAL, and must be one of: jid|group|subscription
 * 
 * If the 'type' is 'jid', then the 'value' must contain a valid JID.
 * JIDs are to be matched in the following order:
 * 
 * - <user@domain/resource> (only that resource matches)
 * - <user@domain> (any resource matches)
 * - <domain/resource> (only that resource matches)
 * - <domain> (the domain itself matches, as does any user@domain or domain/resource)
 * 
 * If the 'type' is 'group', then the 'value' should contain the name of a group in the user's roster.
 * 
 * If the 'type' is 'subscription', then the 'value' must be one of: both|to|from|none
 * 
 * The 'action' attribute is MANDATORY and must be one of: allow|deny
 * 
 * The 'order' attribute is MANDATORY and must be a non-negative integer that is unique among all items in the list.
 * List items are processed by the server according to the 'order' attribute in ascending order. (0 before 1, etc)
 * Once the server matches a privacy item in the list, it obeys the item and ceases processing.
 * 
 * The privacy item may contain one or more child elements that specify more granular blocking control:
 * 
 * - <message/> (blocks incoming message stanzas)
 * - <iq/> (blocks incoming IQ stanzas)
 * - <presence-in/> (blocks incoming presence notifications)
 * - <presence-out/> (blocks outgoing presence notifications)
**/
+ (NSXMLElement *)privacyItemWithAction:(NSString *)action order:(NSUInteger)order;
+ (NSXMLElement *)privacyItemWithType:(NSString *)type
                                value:(NSString *)value
                               action:(NSString *)action
                                order:(NSUInteger)order;

+ (void)blockIQs:(NSXMLElement *)privacyItem;
+ (void)blockMessages:(NSXMLElement *)privacyItem;
+ (void)blockPresenceIn:(NSXMLElement *)privacyItem;
+ (void)blockPresenceOut:(NSXMLElement *)privacyItem;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol XMPPPrivacyDelegate
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
 * with domain=XMPPPrivacyErrorDomain and code from the XMPPPrivacyErrorCode enumeration.
**/

- (void)xmppPrivacy:(XMPPPrivacy *)sender didReceiveListNames:(NSArray *)listNames;
- (void)xmppPrivacy:(XMPPPrivacy *)sender didNotReceiveListNamesDueToError:(id)error;

- (void)xmppPrivacy:(XMPPPrivacy *)sender didReceiveListWithName:(NSString *)name items:(NSArray *)items;
- (void)xmppPrivacy:(XMPPPrivacy *)sender didNotReceiveListWithName:(NSString *)name error:(id)error;

- (void)xmppPrivacy:(XMPPPrivacy *)sender didReceivePushWithListName:(NSString *)name;

- (void)xmppPrivacy:(XMPPPrivacy *)sender didSetActiveListName:(NSString *)name;
- (void)xmppPrivacy:(XMPPPrivacy *)sender didNotSetActiveListName:(NSString *)name error:(id)error;

- (void)xmppPrivacy:(XMPPPrivacy *)sender didSetDefaultListName:(NSString *)name;
- (void)xmppPrivacy:(XMPPPrivacy *)sender didNotSetDefaultListName:(NSString *)name error:(id)error;

- (void)xmppPrivacy:(XMPPPrivacy *)sender didSetListWithName:(NSString *)name;
- (void)xmppPrivacy:(XMPPPrivacy *)sender didNotSetListWithName:(NSString *)name error:(id)error;

@end
