//
//  XMPPHTTPFileUpload.h
//  Mangosta
//
//  Created by Andres Canal on 5/19/16.
//  Copyright © 2016 Inaka. All rights reserved.
//

#import "XMPPSlot.h"
#import "XMPPIDTracker.h"
#import "XMPPModule.h"

static NSString *const XMPPHTTPFileUploadNamespace = @"urn:xmpp:http:upload";

@interface XMPPHTTPFileUpload : XMPPModule {

	XMPPIDTracker *responseTracker;

}

@property(nonatomic, readonly, copy) NSString *serviceName;

- (id)initWithServiceName:(NSString *)serviceName;
- (id)initWithServiceName:(NSString *)serviceName dispatchQueue:(dispatch_queue_t)queue;

- (void)requestSlotForFilename:(NSString *) filename size:(NSInteger) size contentType:(NSString*) contentType;

@end

@protocol XMPPHTPPFileUploadDelegate <NSObject>
@optional

- (void)xmppHTTPFileUpload:(XMPPHTTPFileUpload *)sender didAssignSlot:(XMPPSlot *)slot;
- (void)xmppHTTPFileUpload:(XMPPHTTPFileUpload *)sender didFailToAssignSlotWithError:(XMPPIQ *) iqError;

@end
