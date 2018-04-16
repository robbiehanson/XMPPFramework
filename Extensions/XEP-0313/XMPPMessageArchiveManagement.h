//
//  XMPPMessageArchiveManagement.h
//
//  Created by Andres Canal on 4/8/16.
//  Copyright © 2016 Inaka. All rights reserved.
//

#import "XMPPModule.h"
#import "XMPPResultSet.h"
#import "XMPPIQ.h"
@import KissXML;

@class XMPPIDTracker;
@class XMPPMessage;


NS_ASSUME_NONNULL_BEGIN

/** 'urn:xmpp:mam:2' */
extern NSString *const XMLNS_XMPP_MAM;

@interface XMPPMessageArchiveManagement : XMPPModule

/**
 When this is set to 0 (the default), the module will finish retrieving messages after receiving the first page IQ result.
 Setting it to a non-zero value will cause the module to automatically repeat the query for further pages of specified size until a "fin" result with "complete=true" attribute is received.
 Use NSNotFound to indicate that there is no client-side page size preference.
 */
@property (readwrite, assign) NSInteger resultAutomaticPagingPageSize;

- (void)retrieveMessageArchiveWithFields:(nullable NSArray<NSXMLElement*> *)fields
                           withResultSet:(nullable XMPPResultSet *)resultSet;

- (void)retrieveMessageArchiveAt:(nullable XMPPJID *)archiveJID
                      withFields:(nullable NSArray<NSXMLElement*> *)fields
                   withResultSet:(nullable XMPPResultSet *)resultSet;

- (void)retrieveFormFields;

+ (NSXMLElement *)fieldWithVar:(NSString *)var
                          type:(nullable NSString *)type
                      andValue:(NSString *)value;

@end

@protocol XMPPMessageArchiveManagementDelegate
@optional
- (void)xmppMessageArchiveManagement:(XMPPMessageArchiveManagement *)xmppMessageArchiveManagement didFinishReceivingMessagesWithSet:(XMPPResultSet *)resultSet;
- (void)xmppMessageArchiveManagement:(XMPPMessageArchiveManagement *)xmppMessageArchiveManagement didReceiveMAMMessage:(XMPPMessage *)message;
- (void)xmppMessageArchiveManagement:(XMPPMessageArchiveManagement *)xmppMessageArchiveManagement didFailToReceiveMessages:(nullable XMPPIQ *)error;

- (void)xmppMessageArchiveManagement:(XMPPMessageArchiveManagement *)xmppMessageArchiveManagement didReceiveFormFields:(XMPPIQ *)iq;
- (void)xmppMessageArchiveManagement:(XMPPMessageArchiveManagement *)xmppMessageArchiveManagement didFailToReceiveFormFields:(XMPPIQ *)iq;
@end

NS_ASSUME_NONNULL_END
