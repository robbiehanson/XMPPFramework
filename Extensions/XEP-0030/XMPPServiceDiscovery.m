//
//  XMPPServiceDiscovery.m
//  Mangosta
//
//  Created by Andres Canal on 4/27/16.
//  Copyright © 2016 Inaka. All rights reserved.
//

#import "XMPPServiceDiscovery.h"
#import "XMPPIQ+XEP_0030.h"
#import "XMPPIDTracker.h"
#import "XMPPConstants.h"

@implementation XMPPServiceDiscovery

- (BOOL)activate:(XMPPStream *)aXmppStream {
	
	if ([super activate:aXmppStream]) {
		xmppIDTracker = [[XMPPIDTracker alloc] initWithDispatchQueue:moduleQueue];
		
		return YES;
	}
	
	return NO;
}

- (void)deactivate {
	dispatch_block_t block = ^{ @autoreleasepool {
		
		[xmppIDTracker removeAllIDs];
		xmppIDTracker = nil;
		
	}};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_sync(moduleQueue, block);
	
	[super deactivate];
}

- (void) discoverWithIQ:(XMPPIQ *) infoOrItem {
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		NSString *iqID = [infoOrItem elementID];
		[xmppIDTracker addID:iqID
					  target:self
					selector:@selector(handleDiscovery:withInfo:)
					 timeout:60.0];
		
		[xmppStream sendElement:infoOrItem];
	}};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (void)discoverInformationAboutJID:(XMPPJID *)jid{
	[self discoverWithIQ:[XMPPIQ discoverInfoAssociatedWithJID:jid]];
}


- (void)discoverItemsAssociatedWithJID:(XMPPJID *)jid{
	[self discoverWithIQ:[XMPPIQ discoverItemsAssociatedWithJID:jid]];
}

- (void)handleDiscovery:(XMPPIQ *)iq withInfo:(id <XMPPTrackingInfo>)info{

	if ([[iq type] isEqualToString:@"result"]){
		NSXMLElement *query = [iq elementForName:@"query"];
		NSArray *items = [query children];

		if ([query.xmlns isEqualToString:XMPPDiscoInfoNamespace]) {
			[multicastDelegate xmppServiceDiscovery:self didDiscoverInformation:items];
		} else {
			[multicastDelegate xmppServiceDiscovery:self didDiscoverItems:items];
		}

	} else {
		[multicastDelegate xmppServiceDiscovery:self didFailToDiscover:iq];
	}
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq {

	NSString *type = [iq type];

	if ([type isEqualToString:@"result"] || [type isEqualToString:@"error"]){
		return [xmppIDTracker invokeForID:[iq elementID] withObject:iq];
	}

	return NO;
}

@end
