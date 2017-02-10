//
//  XMPPTBReconnection.m
//  XMPPFramework
//
//  Created by Andres Canal on 7/5/16.
//  Copyright © 2016 Inaka. All rights reserved.
//

#import "XMPPTBReconnection.h"
#import "XMPPFramework.h"
#import "XMPPIQ.h"

@implementation XMPPTBReconnection

- (void) getAuthToken {
	//		<iq from='crone1@shakespeare.lit/desktop'
	//			      id='create1'
	//			      to='coven@muclight.shakespeare.lit'
	//			    type='get'>
	//			<query xmlns='erlang-solutions.com:xmpp:token-auth:0'/>
	//		</iq>
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		NSString *iqID = [XMPPStream generateUUID];
		NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
		[iq addAttributeWithName:@"id" stringValue:iqID];
		[iq addAttributeWithName:@"to" stringValue:self.xmppStream.myJID.full];
		[iq addAttributeWithName:@"type" stringValue:@"get"];
		
		NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"erlang-solutions.com:xmpp:token-auth:0"];
		[iq addChild:query];
		
		[responseTracker addID:iqID
						target:self
					  selector:@selector(handleGetAuthToken:withInfo:)
					   timeout:60.0];
		
		[xmppStream sendElement:iq];
	}};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (void)handleGetAuthToken:(XMPPIQ *)iq withInfo:(id <XMPPTrackingInfo>)info {
	if ([[iq type] isEqualToString:@"result"]){
		NSXMLElement *items = [iq elementForName:@"items"];
		
		NSMutableDictionary *tokensDictionary = [[NSMutableDictionary alloc] init];
		for (NSXMLElement *element in items.children) {
			tokensDictionary[element.name] = element.stringValue;
		}
		[multicastDelegate xmppTBReconnection:self didReceiveToken:tokensDictionary];
	}else{
		[multicastDelegate xmppTBReconnection:self didFailToReceiveToken:iq];
	}
}

- (BOOL)activate:(XMPPStream *)aXmppStream {
	if ([super activate:aXmppStream]){
		responseTracker = [[XMPPIDTracker alloc] initWithDispatchQueue:moduleQueue];
		
		return YES;
	}
	return NO;
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq {
	NSString *type = [iq type];
	if ([type isEqualToString:@"result"] || [type isEqualToString:@"error"]){
		return [responseTracker invokeForID:[iq elementID] withObject:iq];
	}

	return NO;
}


@end
