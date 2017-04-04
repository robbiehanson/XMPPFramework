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
#import "XMPPIDTracker.h"

NSString *const XMPPHTTPFileUploadNamespace = @"urn:xmpp:http:upload";

@interface XMPPHTTPFileUpload()
@property (nonatomic, strong, readonly) XMPPIDTracker *responseTracker;
@end

@implementation XMPPHTTPFileUpload

- (BOOL)activate:(XMPPStream *)aXmppStream {
	
	if ([super activate:aXmppStream]) {
		_responseTracker = [[XMPPIDTracker alloc] initWithDispatchQueue:moduleQueue];

		return YES;
	}

	return NO;
}

- (void)deactivate {
	dispatch_block_t block = ^{ @autoreleasepool {

		[self.responseTracker removeAllIDs];
		_responseTracker = nil;

	}};

	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_sync(moduleQueue, block);

	[super deactivate];
}

- (void)requestSlotFromService:(XMPPJID*)serviceJID
                      filename:(NSString*)filename
                          size:(NSUInteger)size
                   contentType:(NSString*)contentType {
    NSParameterAssert(filename != nil);
    NSParameterAssert(contentType != nil);
    NSParameterAssert(size > 0);
    NSParameterAssert(serviceJID != nil);
	
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
		XMPPIQ *iq = [XMPPIQ iqWithType:@"get" to:serviceJID elementID:iqID];

		XMPPElement *request = [XMPPElement elementWithName:@"request"];
		[request setXmlns:XMPPHTTPFileUploadNamespace];
        if (filename) {
            [request addChild:[XMPPElement elementWithName:@"filename" stringValue:filename]];
        }
		[request addChild:[XMPPElement elementWithName:@"size" numberValue:[NSNumber numberWithUnsignedInteger:size]]];
        if (contentType) {
            [request addChild:[XMPPElement elementWithName:@"content-type" stringValue:contentType]];
        }
		
		[iq addChild:request];
        
        __weak typeof(self) weakSelf = self;
        __weak id weakMulticast = multicastDelegate;
        [self.responseTracker addID:iqID block:^(id obj, id<XMPPTrackingInfo> info) {
            __typeof__(self) strongSelf = weakSelf;
            if (!strongSelf) { return; }
            XMPPIQ *iq = obj;
            if (![iq isKindOfClass:[XMPPIQ class]]) {
                return;
            }
            dispatch_block_t failBlock = ^{
                [weakMulticast xmppHTTPFileUpload:strongSelf service:serviceJID didFailToAssignSlotWithError:iq];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                [weakMulticast xmppHTTPFileUpload:strongSelf didFailToAssignSlotWithError:iq];
#pragma clang diagnostic pop
            };
            if ([[iq type] isEqualToString:@"result"]){
                XMPPSlot *slot = [[XMPPSlot alloc] initWithIQ:iq];
                if (slot) {
                    [weakMulticast xmppHTTPFileUpload:strongSelf service:serviceJID didAssignSlot:slot];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                    [weakMulticast xmppHTTPFileUpload:strongSelf didAssignSlot:slot];
#pragma clang diagnostic pop
                } else {
                    failBlock();
                }
            } else {
                failBlock();
            }
        } timeout:60.0];
		
		[xmppStream sendElement:iq];
	}};

	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
	NSString *type = [iq type];
	
	if ([type isEqualToString:@"result"] || [type isEqualToString:@"error"])
	{
		return [self.responseTracker invokeForID:[iq elementID] withObject:iq];
	}
	
	return NO;
}

@end

@implementation XMPPHTTPFileUpload (Deprecated)

- (instancetype)initWithServiceName:(NSString *)serviceName {
    return [self initWithServiceName:serviceName dispatchQueue:nil];
}

- (instancetype)initWithServiceName:(NSString *)serviceName dispatchQueue:(dispatch_queue_t)queue {
    NSParameterAssert(serviceName != nil);
    
    if ((self = [super initWithDispatchQueue:queue])){
        _serviceName = [serviceName copy];
    }
    
    return self;
}

- (void)requestSlotForFilename:(NSString*)filename
                          size:(NSUInteger)size
                   contentType:(NSString*) contentType {
    XMPPJID *uploadService = [XMPPJID jidWithString:self.serviceName];
    NSParameterAssert(uploadService != nil);
    if (!uploadService) { return; }
    [self requestSlotFromService:uploadService filename:filename size:size contentType:contentType];
}

@end
