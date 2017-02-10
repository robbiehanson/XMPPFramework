//
//  XMPPServiceDiscovery.h
//  Mangosta
//
//  Created by Andres Canal on 4/27/16.
//  Copyright © 2016 Inaka. All rights reserved.
//

#import <XMPPFramework/XMPPFramework.h>

@class XMPPIDTracker;

@interface XMPPServiceDiscovery : XMPPModule {
	XMPPIDTracker *xmppIDTracker;
}

- (void)discoverInformationAboutJID:(nonnull XMPPJID *)jid;
- (void)discoverItemsAssociatedWithJID:(nonnull XMPPJID *)jid;

@end

@protocol XMPPServiceDiscoveryDelegate

@optional

- (void)xmppServiceDiscovery:(nonnull XMPPServiceDiscovery *)sender didDiscoverInformation:(nonnull NSArray<NSXMLElement *> *)items;
- (void)xmppServiceDiscovery:(nonnull XMPPServiceDiscovery *)sender didDiscoverItems:(nonnull NSArray <NSXMLElement *>*)items;

- (void)xmppServiceDiscovery:(nonnull XMPPServiceDiscovery *)sender didFailToDiscover:(nonnull XMPPIQ *)iq;

@end