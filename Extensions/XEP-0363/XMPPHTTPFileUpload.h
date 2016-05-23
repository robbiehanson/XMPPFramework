//
//  XMPPHTTPFileUpload.h
//  Mangosta
//
//  Created by Andres Canal on 5/19/16.
//  Copyright © 2016 Inaka. All rights reserved.
//

#import <XMPPFramework/XMPPFramework.h>
#import "XMPPSlot.h"
#import "XMPPIDTracker.h"

static NSString *const XMPPHTTPFileUploadNamespace = @"urn:xmpp:http:upload";

@interface XMPPHTTPFileUpload : XMPPModule {

	XMPPIDTracker *responseTracker;

}

- (void)requestSlotForFile:(NSString *) filename size:(NSInteger) size contentType:(NSString*) contentType;

@end

@protocol XMPPHTPPFileUploadDelegate <NSObject>
@optional

- (void)xmppHTTPFileUpload:(XMPPHTTPFileUpload *)sender didAssignSlot:(XMPPSlot *)slot;
- (void)xmppHTTPFileUpload:(XMPPHTTPFileUpload *)sender didFailToAssignSlotWithError:(XMPPIQ *) iqError;

@end