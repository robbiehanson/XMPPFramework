#import <Foundation/Foundation.h>
#import "XMPP.h"

#define _XMPP_PUB_SUB_H

@interface XMPPPubSub : XMPPModule

/**
 * Returns whether or not the given message is a PubSub event message.
**/
+ (BOOL)isPubSubMessage:(XMPPMessage *)message;

/**
 * Creates a PubSub module with the JID of the PubSub service.
 * This JID will be the 'to' attribute of outgoing <iq/> element(s).
 * 
 * If you're creating a PEP module, you should pass nil as the serviceJID.
 * If you're creating a normal PubSub module, you should pass the JID of the PubSub service.
 * 
 * If you're connected to server 'domain.tld', then the PubSub JID is typically something like 'pubsub.domain.tld'.
 * However, the exact format of the JID varies from server to server, and is often configurable.
 * If you don't know the PubSub JID beforehand, you may need to use service discovery to find it.
**/
- (id)initWithServiceJID:(XMPPJID *)aServiceJID;
- (id)initWithServiceJID:(XMPPJID *)aServiceJID dispatchQueue:(dispatch_queue_t)queue;

/**
 * The JID of the PubSub server the module is to communicate with.
**/
@property (nonatomic, strong, readonly) XMPPJID *serviceJID;

/**
 * Sends a subscription request for the given node name.
 *
 * @param node
 * 
 *     The name of the node to subscribe to.
 *     This may be a leaf node or, if supported by the server, a collection node.
 *
 * @param myBareOrFullJid
 *
 *     When you subscribe to a PubSub node, you can subscribe with either
 *     your bare jid (username@domain.tld) or your full jid (username@domain.tld/resource).
 *
 *     If you subscribe with your bare jid, then all resources are subscribed.
 *     For example, if you subscribe to "/MyTown/CornerCoffeeShop" with your bare jid,
 *     then your "home" resource will be subscribed, as well as your "work" and "mobile" resources.
 *     No matter what device you sign into your account with, you'll receive pubsub updates.
 *
 *     Contrast this with subscribing with your full jid. This subscribes you only for the current resource.
 *     Using the example from above, only the "home" resource would receive pubsub updates for the node.
 *     
 *     If you don't pass a JID, the method defaults to using the full JID.
 * 
 * @param options
 *
 *     The optional options dictionary allows you to provide the subscription options in the subscription stanza.
 *     This corresponds to XEP-0060, Section 6.3.7: Subscribe and Configure
 * 
 *     To use example 71 from the spec, you would pass the following dictionary:
 * 
 *     @{ @"pubsub#deliver"      : @(YES),
 *        @"pubsub#digest"       : @(NO),
 *        @"pubsub#include_body" : @(NO),
 *        @"pubsub#show-values"  : @[ @"chat", @"online", @"away" ] }
 * 
 * @return uuid
 * 
 *     The return value is the unique elementID of the IQ stanza that was sent.
 *
 * The server's response to the request will be reported via the appropriate delegate methods.
 *
 * @see xmppPubSub:didSubscribeToNode:withResult:
 * @see xmppPubSub:didNotSubscribeToNode:withError:
**/
- (NSString *)subscribeToNode:(NSString *)node;
- (NSString *)subscribeToNode:(NSString *)node withJID:(XMPPJID *)myBareOrFullJid;
- (NSString *)subscribeToNode:(NSString *)node withJID:(XMPPJID *)myBareOrFullJid options:(NSDictionary *)options;

/**
 * Sends an unsubscribe request for the given node name.
 * 
 * @param node
 *
 *     The name of the node to unsubscribe from.
 *     This should be the same node name you used when you subscribed.
 * 
 * @param myBareOrFullJid
 *
 *     The appropriate jid that matches the subscription.
 *     This should be the same jid you used when you subscribed.
 *     
 *     If you don't pass a JID, the method defaults to using the full JID.
 * 
 * @param subid
 *
 *     If a subscription identifier (subid) is associated with the subscription,
 *     the unsubscribe request may be required to include the appropriate 'subid' attribute.
 *     The subid value was returned by the server in the original subscribe response,
 *     and can also be obtained by retrieving the subscription(s) from the server.
 * 
 *     XMPPIQ+XEP_0060 has a category method named "pubsubid" which conveniently
 *     extracts the subid value from a subscription response.
 * 
 * @return uuid
 *
 *     The return value is the unique elementID of the IQ stanza that was sent.
 * 
 * The server's response to the request will be reported via the appropriate delegate methods.
 * 
 * @see xmppPubSub:didUnsubscribeFromNode:withResult:
 * @see xmppPubSub:didNotUnsubscribeFromNode:(NSString *)node withError:
**/
- (NSString *)unsubscribeFromNode:(NSString *)node;
- (NSString *)unsubscribeFromNode:(NSString *)node withJID:(XMPPJID *)myBareOrFullJid;
- (NSString *)unsubscribeFromNode:(NSString *)node withJID:(XMPPJID *)myBareOrFullJid subid:(NSString *)subid;

/**
 * Fetches the current PubSub subscriptions from the server.
 * You can fetch all subscriptions, or just subscriptions for a particular node.
 *
 * Keep in mind that your PubSub subscriptions don't typically disappear when you disconnect.
 * That is, your subscriptions remain intact as the client connects and disconnects.
 *
 * @param node
 * 
 *     Optional node name if you wish to only retrieve subscriptions for a particular node.
 *
 * @return uuid
 *
 *     The return value is the unique elementID of the IQ stanza that was sent.
 * 
 * The server's response to the request will be reported via the appropriate delegate methods.
 *
 * @see xmppPubSub:didRetrieveSubscriptions:
 * @see xmppPubSub:didNotRetrieveSubscriptions:
 *
 * @see xmppPubSub:didRetrieveSubscriptions:forNode:
 * @see xmppPubSub:didNotRetrieveSubscriptions:forNode:
**/
- (NSString *)retrieveSubscriptions;
- (NSString *)retrieveSubscriptionsForNode:(NSString *)node;

/**
 * @param node
 * 
 *     The name of the subscibed node for to configure the subscription.
 *     This should be the same node name you used when you subscribed.
 * 
 * @param myBareOrFullJid
 *
 *     The appropriate jid that matches the subscription.
 *     This should be the same jid you used when you subscribed.
 *
 *     If you don't pass a JID, the method defaults to using the full JID.
 *
 * @param subid
 *
 *     If a subscription identifier (subid) is associated with the subscription,
 *     the configure request may be required to include the appropriate 'subid' attribute.
 *     The subid value was returned by the server in the original subscribe response,
 *     and can also be obtained by retrieving the subscription(s) from the server.
 *
 *     XMPPIQ+XEP_0060 has a category method named "pubsubid" which conveniently
 *     extracts the subid value from a subscription response.
 * 
 * @return uuid
 *
 *     The return value is the unique elementID of the IQ stanza that was sent.
 *
 * The server's response to the request will be reported via the appropriate delegate methods.
 *
 * @see xmppPubSub:didConfigureSubscriptionToNode:withResult:
 * @see xmppPubSub:didNotConfigureSubscriptionToNode:withError:
**/
- (NSString *)configureSubscriptionToNode:(NSString *)node
                                  withJID:(XMPPJID *)myBareOrFullJid
                                    subid:(NSString *)subid
                                  options:(NSDictionary *)options;

/**
 * Publishes the entry to the given node.
 * 
 * If the server supports automatic node creation, and the node does not yet exist,
 * the server may automatically create the node with the default configuration.
 * 
 * @param node
 * 
 *     The name of the node to publish to.
 * 
 * @param entry
 * 
 *     The entry you wish to publish.
 *     This is the xml tree that will go inside the <item/>.
 * 
 * @param itemID
 *
 *     This corresponds to the unique id of the published item.
 *     If you pass the same itemID as a previously published item, then the new entry will replace the old one.
 *     If you don't pass an itemID, the the server will automatically generate a unique itemID for you.
 * 
 * @param options
 *     
 *     You may optionally pass publish options as well.
 *     This corresponds with section 7.1.5 of XEP-0060.
 *     Options are passed as a dictionary of key:value(s) pairs.
 *
 *     For example, if you wanted to include the following publish options (from XEP-0223):
 *     <publish-options>
 *       <x xmlns='jabber:x:data' type='submit'>
 *         <field var='FORM_TYPE' type='hidden'>
 *           <value>http://jabber.org/protocol/pubsub#publish-options</value>
 *         </field>
 *         <field var='pubsub#persist_items'>
 *           <value>true</value>
 *         </field>
 *         <field var='pubsub#access_model'>
 *           <value>whitelist</value>
 *         </field>
 *       </x>
 *     </publish-options>
 * 
 *     Then you would simply pass the following dictionary:
 *     @{ @"pubsub#persist_items" : @(YES),
 *        @"pubsub#access_model " : @"whitelist" }
 *
 * @return uuid
 *
 *     The return value is the unique elementID of the IQ stanza that was sent.
 * 
 * The server's response to the request will be reported via the appropriate delegate methods.
 * 
 * @see xmppPubSub:didPublishToNode:withResult:
 * @see xmppPubSub:didNotPublishToNode:withError:
**/
- (NSString *)publishToNode:(NSString *)node entry:(NSXMLElement *)entry;
- (NSString *)publishToNode:(NSString *)node entry:(NSXMLElement *)entry withItemID:(NSString *)itemId;
- (NSString *)publishToNode:(NSString *)node
                      entry:(NSXMLElement *)entry
                 withItemID:(NSString *)itemId
                    options:(NSDictionary *)options;

/**
 * Creates the given node with optional options.
 * 
 * @param node
 *
 *     The name of the node to create.
 * 
 * @param options
 * 
 *     You may optionally pass configure options as well.
 *     This corresponds with section 8.1.3 of XEP-0060.
 *     Options are passed as a dictionary of key:value(s) pairs.
 *
 * @return uuid
 *
 *     The return value is the unique elementID of the IQ stanza that was sent.
 *
 * The server's response to the request will be reported via the appropriate delegate methods.
 *
 * @see xmppPubSub:didCreateNode:withIQ:
 * @see xmppPubSub:didNotCreateNode:withError:
**/
- (NSString *)createNode:(NSString *)node;
- (NSString *)createNode:(NSString *)node withOptions:(NSDictionary *)options;

/**
 * Deletes the given node.
 * 
 * @param node
 *
 *     The name of the node to delete.
 *     This should be the same node name you used when you created it.
 *
 * @return uuid
 *
 *     The return value is the unique elementID of the IQ stanza that was sent.
 *
 * The server's response to the request will be reported via the appropriate delegate methods.
 *
 * @see xmppPubSub:didDeleteNode:withIQ:
 * @see xmppPubSub:didNotDeleteNode:withError:
**/
- (NSString *)deleteNode:(NSString *)node;

/**
 * Configures the given node.
 * 
 * @param node
 *
 *     The name of the node to configure.
 *     This should be the same node name you used when you created it.
 *
 * @param options
 *
 *     Options are passed as a dictionary of key:value(s) pairs.
 *
 * @return uuid
 *
 *     The return value is the unique elementID of the IQ stanza that was sent.
 *
 * The server's response to the request will be reported via the appropriate delegate methods.
 *
 * @see xmppPubSub:didConfigureNode:withIQ:
 * @see xmppPubSub:didNotConfigureNode:withError:
**/
- (NSString *)configureNode:(NSString *)node withOptions:(NSDictionary *)options;

/**
 * Retrieves items from given node.
 *
 * @param node
 *
 *     The name of the node to retrieve items from.
 *     This should be the same node name you used when you created it.
 *
 * @param withItemIDs
 *
 *     This corresponds to a list of unique ids of previously published items.
 *     The server will return the previously published items for those that exists.
 *     If none of the items exists, an empty items list will be returned.
 *     If you don't pass any itemIDs, the server will retrieve all items on the given node
 *
 * @return uuid
 *
 *     The return value is the unique elementID of the IQ stanza that was sent.
 *
 * The server's response to the request will be reported via the appropriate delegate methods.
 *
 * @see xmppPubSub:didRetrieveItems:fromNode:
 * @see xmppPubSub:didNotRetrieveItems:fromNode:
 **/
- (NSString *)retrieveItemsFromNode:(NSString *)node;
- (NSString *)retrieveItemsFromNode:(NSString *)node withItemIDs:(NSArray *)itemIds;

@end

@protocol XMPPPubSubDelegate
@optional

- (void)xmppPubSub:(XMPPPubSub *)sender didSubscribeToNode:(NSString *)node withResult:(XMPPIQ *)iq;
- (void)xmppPubSub:(XMPPPubSub *)sender didNotSubscribeToNode:(NSString *)node withError:(XMPPIQ *)iq;

- (void)xmppPubSub:(XMPPPubSub *)sender didUnsubscribeFromNode:(NSString *)node withResult:(XMPPIQ *)iq;
- (void)xmppPubSub:(XMPPPubSub *)sender didNotUnsubscribeFromNode:(NSString *)node withError:(XMPPIQ *)iq;

- (void)xmppPubSub:(XMPPPubSub *)sender didRetrieveSubscriptions:(XMPPIQ *)iq;
- (void)xmppPubSub:(XMPPPubSub *)sender didNotRetrieveSubscriptions:(XMPPIQ *)iq;

- (void)xmppPubSub:(XMPPPubSub *)sender didRetrieveSubscriptions:(XMPPIQ *)iq forNode:(NSString *)node;
- (void)xmppPubSub:(XMPPPubSub *)sender didNotRetrieveSubscriptions:(XMPPIQ *)iq forNode:(NSString *)node;

- (void)xmppPubSub:(XMPPPubSub *)sender didConfigureSubscriptionToNode:(NSString *)node withResult:(XMPPIQ *)iq;
- (void)xmppPubSub:(XMPPPubSub *)sender didNotConfigureSubscriptionToNode:(NSString *)node withError:(XMPPIQ *)iq;

- (void)xmppPubSub:(XMPPPubSub *)sender didPublishToNode:(NSString *)node withResult:(XMPPIQ *)iq;
- (void)xmppPubSub:(XMPPPubSub *)sender didNotPublishToNode:(NSString *)node withError:(XMPPIQ *)iq;

- (void)xmppPubSub:(XMPPPubSub *)sender didCreateNode:(NSString *)node withResult:(XMPPIQ *)iq;
- (void)xmppPubSub:(XMPPPubSub *)sender didNotCreateNode:(NSString *)node withError:(XMPPIQ *)iq;

- (void)xmppPubSub:(XMPPPubSub *)sender didDeleteNode:(NSString *)node withResult:(XMPPIQ *)iq;
- (void)xmppPubSub:(XMPPPubSub *)sender didNotDeleteNode:(NSString *)node withError:(XMPPIQ *)iq;

- (void)xmppPubSub:(XMPPPubSub *)sender didConfigureNode:(NSString *)node withResult:(XMPPIQ *)iq;
- (void)xmppPubSub:(XMPPPubSub *)sender didNotConfigureNode:(NSString *)node withError:(XMPPIQ *)iq;

- (void)xmppPubSub:(XMPPPubSub *)sender didRetrieveItems:(XMPPIQ *)iq fromNode:(NSString *)node;
- (void)xmppPubSub:(XMPPPubSub *)sender didNotRetrieveItems:(XMPPIQ *)iq fromNode:(NSString *)node;

- (void)xmppPubSub:(XMPPPubSub *)sender didReceiveMessage:(XMPPMessage *)message;

@end
