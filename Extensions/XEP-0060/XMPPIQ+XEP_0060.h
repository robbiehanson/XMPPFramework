#import <Foundation/Foundation.h>
#import "XMPPIQ.h"

#define XMLNS_PUBSUB                   @"http://jabber.org/protocol/pubsub"
#define XMLNS_PUBSUB_OWNER             @"http://jabber.org/protocol/pubsub#owner"
#define XMLNS_PUBSUB_EVENT             @"http://jabber.org/protocol/pubsub#event"
#define XMLNS_PUBSUB_NODE_CONFIG       @"http://jabber.org/protocol/pubsub#node_config"
#define XMLNS_PUBSUB_PUBLISH_OPTIONS   @"http://jabber.org/protocol/pubsub#publish-options"
#define XMLNS_PUBSUB_SUBSCRIBE_OPTIONS @"http://jabber.org/protocol/pubsub#subscribe_options"

@interface XMPPIQ (XEP_0060)

/**
 * Extracts the 'subid' from a PubSub subscription response.
 * 
 * For example, if we sent a PubSub subscription request for node "princely_musings",
 * and the server returned this response:
 * 
 * <iq type='result' from='pubsub.shakespeare.lit' to='francisco@denmark.lit/barracks' id='sub1'>
 *   <pubsub xmlns='http://jabber.org/protocol/pubsub'>
 *     <subscription
 *         node='princely_musings'
 *         jid='francisco@denmark.lit'
 *         subid='ba49252aaa4f5d320c24d3766f0bdcade78c78d3'
 *         subscription='subscribed'/>
 *   </pubsub>
 * </iq>
 * 
 * Then this method would return "ba49252aaa4f5d320c24d3766f0bdcade78c78d3".
 * 
 * It is common to store the subid as it often a required attribute when unsubscribing.
**/
- (NSString *)pubsubid;

@end
