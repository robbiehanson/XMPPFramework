//
//  XMPPMessageArchiveManagement.m
//
//  Created by Andres Canal on 4/8/16.
//  Copyright © 2016 Inaka. All rights reserved.
//

#import "XMPPMessageArchiveManagement.h"
#import "XMPPFramework.h"
#import "XMPPLogging.h"
#import "XMPPIDTracker.h"

#define XMLNS_XMPP_MAM @"urn:xmpp:mam:1"

@implementation XMPPMessageArchiveManagement

- (void)retrieveMessageArchiveWithFields:(NSArray *)fields withResultSet:(XMPPResultSet *)resultSet {
	dispatch_block_t block = ^{
		
		if ([xmppIDTracker numberOfIDs] == 0) {
			
			XMPPIQ *iq = [XMPPIQ iqWithType:@"set"];
			[iq addAttributeWithName:@"id" stringValue:[XMPPStream generateUUID]];
			
			DDXMLElement *queryElement = [DDXMLElement elementWithName:@"query" xmlns:XMLNS_XMPP_MAM];
			[queryElement addAttributeWithName:@"queryId" stringValue:[XMPPStream generateUUID]];
			[iq addChild:queryElement];
			
			DDXMLElement *xElement = [DDXMLElement elementWithName:@"x" xmlns:@"jabber:x:data"];
			[xElement addAttributeWithName:@"type" stringValue:@"submit"];
			[xElement addChild:[XMPPMessageArchiveManagement fieldWithVar:@"FORM_TYPE" type:@"hidden" andValue:@"urn:xmpp:mam:1"]];
			
			for (DDXMLElement *field in fields) {
				[xElement addChild:field];
			}
			
			[queryElement addChild:xElement];
			
			if (resultSet) {
				[queryElement addChild:resultSet];
			}

			[xmppIDTracker addElement:iq
							   target:self
							 selector:@selector(enableMessageArchiveIQ:withInfo:)
							  timeout:60];
			
			[xmppStream sendElement:iq];
		}
	};
	
	if (dispatch_get_specific(moduleQueueTag)) {
		block();
	} else {
		dispatch_sync(moduleQueue, block);
	}
	
}

+ (DDXMLElement *)fieldWithVar:(NSString *)var type:(NSString *)type andValue:(NSString *)value {
	DDXMLElement *field = [DDXMLElement elementWithName:@"field"];
	[field addAttributeWithName:@"var" stringValue:var];
	
	if(type){
		[field addAttributeWithName:@"type" stringValue:type];
	}
	
	DDXMLElement *elementValue = [DDXMLElement elementWithName:@"value"];
	elementValue.stringValue = value;
	
	[field addChild:elementValue];
	
	return field;
}

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
	
	if (dispatch_get_specific(moduleQueueTag)) {
		block();
	} else {
		dispatch_sync(moduleQueue, block);
	}
	
	[super deactivate];
}

#pragma mark XMPPStream Delegate

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
	NSString *type = [iq type];
	if ([type isEqualToString:@"result"] || [type isEqualToString:@"error"])
	{
		return [xmppIDTracker invokeForID:[iq elementID] withObject:iq];
	}
	
	return NO;
}

- (void)enableMessageArchiveIQ:(XMPPIQ *)iq withInfo:(XMPPBasicTrackingInfo *)trackerInfo {
	
	if ([[iq type] isEqualToString:@"result"]) {
		
		DDXMLElement *finElement = [iq elementForName:@"fin" xmlns:XMLNS_XMPP_MAM];
		DDXMLElement *setElement = [finElement elementForName:@"set" xmlns:@"http://jabber.org/protocol/rsm"];
		
		XMPPResultSet *resultSet = [XMPPResultSet resultSetFromElement:setElement];
		[multicastDelegate xmppMessageArchiveManagement:self didFinishReceivingMessagesWithSet:resultSet];
	} else {
		[multicastDelegate xmppMessageArchiveManagement:self didReceiveError:iq];
	}
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message {
	DDXMLElement *result = [message elementForName:@"result" xmlns:XMLNS_XMPP_MAM];
	DDXMLElement *forwarded = [result elementForName:@"forwarded"];
	
	if (forwarded) {
		[multicastDelegate xmppMessageArchiveManagement:self didReceiveMAMMessage:message];
	}
}

@end
