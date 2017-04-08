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
#import "XMPPLogging.h"

// Log levels: off, error, warn, info, verbose
#if DEBUG
static const int xmppLogLevel = XMPP_LOG_LEVEL_INFO | XMPP_LOG_FLAG_SEND_RECV; // | XMPP_LOG_FLAG_TRACE;
#else
static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

NSString *const XMPPHTTPFileUploadNamespace = @"urn:xmpp:http:upload";
NSString *const XMPPHTTPFileUploadErrorDomain = @"XMPPHTTPFileUploadErrorDomain";

NSString* StringForXMPPHTTPFileUploadErrorCode(XMPPHTTPFileUploadErrorCode errorCode) {
    switch (errorCode) {
        case XMPPHTTPFileUploadErrorCodeUnknown:
            return @"Unknown Error";
        case XMPPHTTPFileUploadErrorCodeNoResponse:
            return @"No Response";
        case XMPPHTTPFileUploadErrorCodeBadResponse:
            return @"Bad Response";
    }
}

static NSError *ErrorForCode(XMPPHTTPFileUploadErrorCode errorCode) {
    NSString *description = StringForXMPPHTTPFileUploadErrorCode(errorCode);
    return [NSError errorWithDomain:XMPPHTTPFileUploadErrorDomain code:errorCode userInfo:@{NSLocalizedDescriptionKey: description}];
}

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
                   contentType:(NSString*)contentType
                           tag:(nullable id)tag {
    __weak typeof(self) weakSelf = self;
    __weak id weakMulticast = multicastDelegate;
    [self requestSlotFromService:serviceJID filename:filename size:size contentType:contentType completion:^(XMPPSlot * _Nullable slot, XMPPIQ * _Nullable resultIq, NSError * _Nullable error) {
        __typeof__(self) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if (!slot) {
            [weakMulticast xmppHTTPFileUpload:strongSelf service:serviceJID didFailToAssignSlotWithError:error response:resultIq tag:tag];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            [weakMulticast xmppHTTPFileUpload:strongSelf didFailToAssignSlotWithError:resultIq];
#pragma clang diagnostic pop
        } else {
            [weakMulticast xmppHTTPFileUpload:strongSelf service:serviceJID didAssignSlot:slot response:resultIq tag:tag];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            [weakMulticast xmppHTTPFileUpload:strongSelf didAssignSlot:slot];
#pragma clang diagnostic pop
        }
    }];
}

- (void)requestSlotFromService:(XMPPJID*)serviceJID
                      filename:(NSString*)filename
                          size:(NSUInteger)size
                   contentType:(NSString*)contentType
                    completion:(void (^_Nonnull)(XMPPSlot * _Nullable slot, XMPPIQ * _Nullable resultIq, NSError * _Nullable error))completion {
    [self requestSlotFromService:serviceJID filename:filename size:size contentType:contentType completion:completion completionQueue:nil];
}

- (void)requestSlotFromService:(XMPPJID*)serviceJID
                      filename:(NSString*)filename
                          size:(NSUInteger)size
                   contentType:(NSString*)contentType
                    completion:(void (^_Nonnull)(XMPPSlot * _Nullable slot, XMPPIQ * _Nullable resultIq, NSError * _Nullable error))completion
               completionQueue:(_Nullable dispatch_queue_t)completionQueue {
    NSParameterAssert(filename != nil);
    NSParameterAssert(contentType != nil);
    NSParameterAssert(size > 0);
    NSParameterAssert(serviceJID != nil);
    NSParameterAssert(completion != nil);
    if (!completion) {
        XMPPLogError(@"XMPPHTTPFileUpload: No completion block specified, aborting...");
        return;
    }
    if (!completionQueue) {
        completionQueue = moduleQueue;
    }
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
        [self.responseTracker addID:iqID block:^(id obj, id<XMPPTrackingInfo> info) {
            __typeof__(self) strongSelf = weakSelf;
            if (!strongSelf) { return; }
            NSError *error = nil;
            XMPPIQ *responseIq = nil;
            XMPPSlot *slot = nil;
            if ([obj isKindOfClass:[XMPPIQ class]]) {
                responseIq = obj;
                if ([responseIq isResultIQ]) {
                    slot = [[XMPPSlot alloc] initWithIQ:responseIq];
                }
                if (!slot) {
                    error = ErrorForCode(XMPPHTTPFileUploadErrorCodeBadResponse);
                }
            } else {
                error = ErrorForCode(XMPPHTTPFileUploadErrorCodeNoResponse);
            }
            if (!slot && !error) {
                error = ErrorForCode(XMPPHTTPFileUploadErrorCodeUnknown);
            }
            
            dispatch_async(completionQueue, ^{
                completion(slot, responseIq, error);
            });
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
    [self requestSlotFromService:uploadService filename:filename size:size contentType:contentType tag:nil];
}

@end
