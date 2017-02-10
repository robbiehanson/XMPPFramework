//
//  XMPPIQ+XEP_0030.m
//  XMPPFramework
//
//  Created by Andres on 7/07/16.
//  Copyright © 2016 Inaka. All rights reserved.
//

#import "XMPPIQ+XEP_0030.h"
#import "NSXMLElement+XMPP.h"
#import "XMPPConstants.h"

@implementation XMPPIQ (XEP_0060)

+ (nonnull XMPPIQ *) discoverItemsAssociatedWithJID:(nonnull XMPPJID *)jid {

	//	<iq type='get'
	//		from='romeo@montague.net/orchard'
	//		to='shakespeare.lit'
	//		id='items1'>
	//		<query xmlns='http://jabber.org/protocol/disco#items'/> // disco#items
	//	</iq>

	NSString *iqID = [XMPPStream generateUUID];
	NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns: XMPPDiscoItemsNamespace];
	return [XMPPIQ iqWithType:@"get" to:jid elementID:iqID child:query];

}

+ (nonnull XMPPIQ *) discoverInfoAssociatedWithJID:(nonnull XMPPJID *)jid {
	
	//	<iq type='get'
	//		from='romeo@montague.net/orchard'
	//		to='shakespeare.lit'
	//		id='items1'>
	//		<query xmlns='http://jabber.org/protocol/disco#info'/> // disco#info
	//	</iq>
	
	NSString *iqID = [XMPPStream generateUUID];
	NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns: XMPPDiscoInfoNamespace];
	return [XMPPIQ iqWithType:@"get" to:jid elementID:iqID child:query];

}

+ (nullable NSArray <NSXMLElement *> *)parseDiscoveredItemsFromIQ:(nonnull XMPPIQ *)iq {
	//	<iq xmlns='jabber:client' from='shakespeare.lit'
	//                              to='test@shakespeare.lit'
	//                              id='items1' type='result'>
	//	   <query xmlns='http://jabber.org/protocol/disco#items'>
	//			<item jid='muc.erlang-solutions.com'/>
	//			<item jid='muclight.erlang-solutions.com'/>
	//			<item jid='pubsub.erlang-solutions.com'/>
	//			<item jid='vjud.erlang-solutions.com'/>
	//		</query>
	//	</iq>

	NSXMLElement *query = [iq elementForName:@"query" xmlns: XMPPDiscoItemsNamespace];
	if(query) {
		return [query elementsForName:@"item"];
	}

	return nil;
}

+ (nullable NSArray <NSXMLElement *> *)parseDiscoveredInfoFromIQ:(nonnull XMPPIQ *)iq {
	//    <iq xmlns='jabber:client' from='shakespeare.lit'
	//								  to='test@shakespeare.lit'
    //                                id='items1' type='result'>
	//      <query xmlns='http://jabber.org/protocol/disco#info'>
	//        <identity category='pubsub' type='pep'/>
	//        <identity category='server' type='im' name='ejabberd'/>
	//        <feature var='erlang-solutions.com:xmpp:token-auth:0'/>
	//        <feature var='http://jabber.org/protocol/disco#info'/>
	//        <feature var='http://jabber.org/protocol/disco#items'/>
	//        <feature var='http://jabber.org/protocol/pubsub'/>
	//        <feature var='urn:xmpp:mam:0'/>
	//        <feature var='urn:xmpp:mam:1'/>
	//      </query>
	//    </iq>

	NSXMLElement *query = [iq elementForName:@"query" xmlns: XMPPDiscoInfoNamespace];
	if(query) {
		return [query children] ? [query children] : ((NSArray <NSXMLElement *> *)[[NSArray alloc] init]);
	}

	return nil;
}

@end
