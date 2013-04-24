/**
 * XEP-0223 : Persistent Storage of Private Data via PubSub
 * 
 * This specification defines best practices for using the XMPP publish-subscribe extension to
 * persistently store private information such as bookmarks and client configuration options.
 * 
 * http://xmpp.org/extensions/xep-0223.html
**/

#import <Foundation/Foundation.h>


@interface XEP_0223 : NSObject

/**
 * This method returns the recommended configuration options to configure a pubsub node for storing private data.
 * It may be passed directly to the publishToNoe:::: method of XMPPPubSub.
**/
+ (NSDictionary *)privateStoragePubSubOptions;

@end
