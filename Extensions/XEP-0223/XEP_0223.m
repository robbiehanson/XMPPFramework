/**
 * XEP-0223 : Persistent Storage of Private Data via PubSub
 *
 * This specification defines best practices for using the XMPP publish-subscribe extension to
 * persistently store private information such as bookmarks and client configuration options.
 *
 * http://xmpp.org/extensions/xep-0223.html
**/

#import "XEP_0223.h"

@implementation XEP_0223

+ (NSDictionary *)privateStoragePubSubOptions
{
	return @{ @"pubsub#persist_items" : @(YES),
	          @"pubsub#access_model"  : @"whitelist" };
}

@end
