//
//  XMPPMessageArchiveManagement.h
//  Mangosta
//
//  Created by Tom Ryan on 4/8/16.
//  Copyright © 2016 Inaka. All rights reserved.
//

#import <XMPPFramework/XMPPFramework.h>
#import <XMPPFramework/XMPPResultSet.h>

@class XMPPIDTracker;
@class XMPPMessage;

@interface XMPPMessageArchiveManagement : XMPPModule {
	XMPPIDTracker *xmppIDTracker;
}

- (void)retrieveMessageArchiveWithFields:(NSArray *)fields withResultSet:(XMPPResultSet *)resultSet;
+ (DDXMLElement *)fieldWithVar:(NSString *)var type:(NSString *)type andValue:(NSString *)value;

@end

@protocol XMPPMessageArchiveManagementDelegate
@optional
- (void)xmppMessageArchiveManagement:(XMPPMessageArchiveManagement *)xmppMessageArchiveManagement didFinishReceivingMessagesWithSet:(XMPPResultSet *)resultSet;
- (void)xmppMessageArchiveManagement:(XMPPMessageArchiveManagement *)xmppMessageArchiveManagement didReceiveMAMMessage:(XMPPMessage *)message;
- (void)xmppMessageArchiveManagement:(XMPPMessageArchiveManagement *)xmppMessageArchiveManagement didReceiveError:(DDXMLElement *)error;
@end