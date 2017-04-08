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

/**
 * @note When using the block-based APIs, the delegate methods will not fire.
 * @note completion will default to moduleQueue
 */
- (void)requestSlotFromService:(XMPPJID*)serviceJID
                      filename:(NSString*)filename
                          size:(NSUInteger)size
                   contentType:(NSString*)contentType
                    completion:(void (^_Nonnull)(XMPPSlot * _Nullable slot, XMPPIQ * _Nullable responseIq, NSError * _Nullable error))completion;

/**
 * @note When using the block-based APIs, the delegate methods will not fire.
 * @note completion will default to moduleQueue
 */
- (void)requestSlotFromService:(XMPPJID*)serviceJID
                      filename:(NSString*)filename
                          size:(NSUInteger)size
                   contentType:(NSString*)contentType
                    completion:(void (^_Nonnull)(XMPPSlot * _Nullable slot, XMPPIQ * _Nullable responseIq, NSError * _Nullable error))completion
               completionQueue:(_Nullable dispatch_queue_t)completionQueue;

/** Tag will be passed back from delegate methods */
- (void)requestSlotFromService:(XMPPJID*)serviceJID
                      filename:(NSString*)filename
                          size:(NSUInteger)size
                   contentType:(NSString*)contentType
                           tag:(nullable id)tag;

@property (nullable, nonatomic, readonly, copy) NSString *serviceName DEPRECATED_MSG_ATTRIBUTE("XMPPHTTPFileUpload can now handle multiple services. Use requestSlotFromService:filename:size:contentType: instead.");

@end

@protocol XMPPHTPPFileUploadDelegate <NSObject>
@optional

- (void)xmppHTTPFileUpload:(XMPPHTTPFileUpload *)sender service:(XMPPJID*)service didAssignSlot:(XMPPSlot *)slot response:(XMPPIQ*)response tag:(nullable id)tag;

- (void)xmppHTTPFileUpload:(XMPPHTTPFileUpload *)sender service:(XMPPJID*)service didFailToAssignSlotWithError:(NSError*)error response:(nullable XMPPIQ*)response tag:(nullable id)tag;

- (void)xmppHTTPFileUpload:(XMPPHTTPFileUpload *)sender didAssignSlot:(XMPPSlot *)slot DEPRECATED_MSG_ATTRIBUTE("XMPPHTPPFileUploadDelegate now handles multiple services. Use xmppHTTPFileUpload:service:didAssignSlot: instead.");
- (void)xmppHTTPFileUpload:(XMPPHTTPFileUpload *)sender didFailToAssignSlotWithError:(nullable XMPPIQ *) iqError DEPRECATED_MSG_ATTRIBUTE("XMPPHTPPFileUploadDelegate now handles multiple services. Use xmppHTTPFileUpload:service:didFailToAssignSlotWithError: instead.");

@end


// MARK: - Error Handling

extern NSString *const XMPPHTTPFileUploadErrorDomain;

typedef NS_ENUM(NSInteger, XMPPHTTPFileUploadErrorCode) {
    /** Catchall for any other errors */
    XMPPHTTPFileUploadErrorCodeUnknown = 0,
    /** This will happen whenever XMPPSlot is nil */
    XMPPHTTPFileUploadErrorCodeBadResponse,
    /** This happens if result is nil or timeout */
    XMPPHTTPFileUploadErrorCodeNoResponse,
};

extern NSString* StringForXMPPHTTPFileUploadErrorCode(XMPPHTTPFileUploadErrorCode errorCode);

// MARK: - Deprecated

@interface XMPPHTTPFileUpload (Deprecated)

- (instancetype)initWithServiceName:(NSString *)serviceName DEPRECATED_MSG_ATTRIBUTE("XMPPHTTPFileUpload can now handle multiple services. Use requestSlotFromService:filename:size:contentType: instead.");
- (instancetype)initWithServiceName:(NSString *)serviceName dispatchQueue:(nullable dispatch_queue_t)queue DEPRECATED_MSG_ATTRIBUTE("XMPPHTTPFileUpload can now handle multiple services. Use requestSlotFromService:filename:size:contentType: instead.");

- (void)requestSlotForFilename:(NSString *)filename
                          size:(NSUInteger)size
                   contentType:(NSString *)contentType DEPRECATED_MSG_ATTRIBUTE("XMPPHTTPFileUpload can now handle multiple services. Use requestSlotFromService:filename:size:contentType: instead.");

@end

NS_ASSUME_NONNULL_END
