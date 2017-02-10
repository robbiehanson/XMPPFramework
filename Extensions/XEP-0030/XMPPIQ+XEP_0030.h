//
//  XMPPIQ+XEP_0030.h
//  XMPPFramework
//
//  Created by Andres on 7/07/16.
//  Copyright © 2016 Inaka. All rights reserved.
//

#import <XMPPFramework/XMPPFramework.h>
#import "XMPPFramework/XMPPJID.h"

@interface XMPPIQ (XEP_0030)

+ (nonnull XMPPIQ *) discoverItemsAssociatedWithJID:(nonnull XMPPJID *)jid;
+ (nonnull XMPPIQ *) discoverInfoAssociatedWithJID:(nonnull XMPPJID *)jid;
+ (nullable NSArray <NSXMLElement *> *)parseDiscoveredItemsFromIQ:(nonnull XMPPIQ *)iq;
+ (nullable NSArray <NSXMLElement *> *)parseDiscoveredInfoFromIQ:(nonnull XMPPIQ *)iq;

@end
