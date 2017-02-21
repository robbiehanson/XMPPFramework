//
//  XMPPHTTPFileUpload.m
//  Mangosta
//
//  Created by Andres Canal on 5/19/16.
//  Copyright © 2016 Inaka. All rights reserved.
//

#import "XMPPHTTPFileUpload.h"
#import "XMPPStream.h"
#import "NSXMLElement+XMPP.h"

@implementation XMPPHTTPFileUpload


- (id)init
{
	// This will cause a crash - it's designed to.
	return [self initWithServiceName:nil dispatchQueue:nil];
}

- (id)initWithDispatchQueue:(dispatch_queue_t)queue
{
	// This will cause a crash - it's designed to.
	return [self initWithServiceName:nil dispatchQueue:queue];
}

- (id)initWithServiceName:(NSString *)serviceName {
	return [self initWithServiceName:serviceName dispatchQueue:nil];
}

- (id)initWithServiceName:(NSString *)serviceName dispatchQueue:(dispatch_queue_t)queue {
	NSParameterAssert(serviceName != nil);
	
	if ((self = [super initWithDispatchQueue:queue])){
		_serviceName = serviceName;
	}
	
	return self;
}

- (BOOL)activate:(XMPPStream *)aXmppStream {
	
	if ([super activate:aXmppStream]) {
		responseTracker = [[XMPPIDTracker alloc] initWithDispatchQueue:moduleQueue];

		return YES;
	}

	return NO;
}

- (void)deactivate {
	dispatch_block_t block = ^{ @autoreleasepool {

		[responseTracker removeAllIDs];
		responseTracker = nil;

	}};

	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_sync(moduleQueue, block);

	[super deactivate];
}


- (void)requestSlotForFilename:(NSString *) filename size:(NSInteger) size contentType:(NSString*) contentType {

	
	
	dispatch_block_t block = ^{ @autoreleasepool {

		//	<iq from='romeo@montague.tld/garden' id='step_03'
		//		  to='upload.montague.tld' type='get'>
		//	   <request xmlns='urn:xmpp:http:upload'>
		//		  <filename>my_juliet.png</filename>
		//		  <size>23456</size>
		//		  <content-type>image/jpeg</content-type>
		//	   </request>
		//	</iq>

		NSString *iqID = [XMPPStream generateUUID];
		XMPPJID *uploadService = [XMPPJID jidWithString:self.serviceName];
		XMPPIQ *iq = [XMPPIQ iqWithType:@"get" to:uploadService elementID:iqID];

		XMPPElement *request = [XMPPElement elementWithName:@"request"];
		[request setXmlns:XMPPHTTPFileUploadNamespace];
		[request addChild:[XMPPElement elementWithName:@"filename" stringValue:filename]];
		[request addChild:[XMPPElement elementWithName:@"size" numberValue:[NSNumber numberWithInteger:size]]];
		[request addChild:[XMPPElement elementWithName:@"content-type" stringValue:contentType]];
		
		[iq addChild:request];

		[responseTracker addID:iqID
						target:self
					  selector:@selector(handleRequestSlot:withInfo:)
					   timeout:60.0];
		
		[xmppStream sendElement:iq];
	}};

	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (void)handleRequestSlot:(XMPPIQ *)iq withInfo:(id <XMPPTrackingInfo>)info{
	if ([[iq type] isEqualToString:@"result"]){
		XMPPSlot *slot = [[XMPPSlot alloc] initWithIQ:iq];
		
		[multicastDelegate xmppHTTPFileUpload:self didAssignSlot:slot];
	} else {
		[multicastDelegate xmppHTTPFileUpload:self didFailToAssignSlotWithError:iq];
	}
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
	NSString *type = [iq type];
	
	if ([type isEqualToString:@"result"] || [type isEqualToString:@"error"])
	{
		return [responseTracker invokeForID:[iq elementID] withObject:iq];
	}
	
	return NO;
}

@end
