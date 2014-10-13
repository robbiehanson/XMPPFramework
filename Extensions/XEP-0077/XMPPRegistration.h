//
// Created by Jonathon Staff on 10/11/14.
// Copyright (c) 2014 Jonathon Staff. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XMPPModule.h"

@class XMPPIDTracker;

#define _XMPP_REGISTRATION_H

@interface XMPPRegistration : XMPPModule
{
  XMPPIDTracker *xmppIDTracker;
}

- (BOOL)changePassword:(NSString *)newPassword;
- (BOOL)cancelRegistrationUsingPassword:(NSString *)password;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - XMPPRegistrationDelegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol XMPPRegistrationDelegate
@optional

- (void)passwordChangeSuccessful:(XMPPRegistration *)sender;
- (void)passwordChangeFailed:(XMPPRegistration *)sender withError:(NSError *)error;

- (void)cancelRegistrationSuccessful:(XMPPRegistration *)sender;
- (void)cancelRegistrationFailed:(XMPPRegistration *)sender withError:(NSError *)error;

@end
