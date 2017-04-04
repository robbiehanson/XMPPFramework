//
//  XMPPHTTPFileUpload.h
//  Mangosta
//
//  Created by Andres Canal on 5/19/16.
//  Copyright © 2016 Inaka. All rights reserved.
//

#import "XMPPSlot.h"
#import "XMPPModule.h"

NS_ASSUME_NONNULL_BEGIN

/** urn:xmpp:http:upload */
extern NSString *const XMPPHTTPFileUploadNamespace;

@interface XMPPHTTPFileUpload : XMPPModule

- (void)requestSlotFromService:(XMPPJID*)serviceJID
                      filename:(NSString*)filename
                          size:(NSUInteger)size
                   contentType:(NSString*)contentType;

@property (nullable, nonatomic, readonly, copy) NSString *serviceName DEPRECATED_MSG_ATTRIBUTE("XMPPHTTPFileUpload can now handle multiple services. Use requestSlotFromService:filename:size:contentType: instead.");

@end

@protocol XMPPHTPPFileUploadDelegate <NSObject>
@optional

- (void)xmppHTTPFileUpload:(XMPPHTTPFileUpload *)sender service:(XMPPJID*)service didAssignSlot:(XMPPSlot *)slot;

- (void)xmppHTTPFileUpload:(XMPPHTTPFileUpload *)sender service:(XMPPJID*)service didFailToAssignSlotWithError:(XMPPIQ *) iqError;


- (void)xmppHTTPFileUpload:(XMPPHTTPFileUpload *)sender didAssignSlot:(XMPPSlot *)slot DEPRECATED_MSG_ATTRIBUTE("XMPPHTPPFileUploadDelegate now handles multiple services. Use xmppHTTPFileUpload:service:didAssignSlot: instead.");
- (void)xmppHTTPFileUpload:(XMPPHTTPFileUpload *)sender didFailToAssignSlotWithError:(XMPPIQ *) iqError DEPRECATED_MSG_ATTRIBUTE("XMPPHTPPFileUploadDelegate now handles multiple services. Use xmppHTTPFileUpload:service:didFailToAssignSlotWithError: instead.");

@end

@interface XMPPHTTPFileUpload (Deprecated)



- (instancetype)initWithServiceName:(NSString *)serviceName DEPRECATED_MSG_ATTRIBUTE("XMPPHTTPFileUpload can now handle multiple services. Use requestSlotFromService:filename:size:contentType: instead.");
- (instancetype)initWithServiceName:(NSString *)serviceName dispatchQueue:(nullable dispatch_queue_t)queue DEPRECATED_MSG_ATTRIBUTE("XMPPHTTPFileUpload can now handle multiple services. Use requestSlotFromService:filename:size:contentType: instead.");

- (void)requestSlotForFilename:(NSString *)filename
                          size:(NSUInteger)size
                   contentType:(NSString *)contentType DEPRECATED_MSG_ATTRIBUTE("XMPPHTTPFileUpload can now handle multiple services. Use requestSlotFromService:filename:size:contentType: instead.");

@end

NS_ASSUME_NONNULL_END
