//
// Created by Jonathon Staff on 10/11/14.
// Copyright (c) 2014 Jonathon Staff. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XMPPModule.h"

@class XMPPIDTracker;

#define _XMPP_REGISTRATION_H

@interface XMPPRegistration : XMPPModule {
  XMPPIDTracker *xmppIDTracker;
}

/**
* This method will attempt to change the current user's password to the new one provided. The
* user *MUST* be authenticated for this to work successfully.
*
* @see passwordChangeSuccessful:
* @see passwordChangeFailed:withError:
*
* @param newPassword The new password for the user
*/
- (BOOL)changePassword:(NSString *)newPassword;

/**
* This method will attempt to cancel the current user's registration. Later implementations
* will provide support for handling authentication challenges by the server. For now,
* simply pass a value of 'nil' in for password, or preferably, use the other cancellation
* method.
*
* @see cancelRegistration
*/
- (BOOL)cancelRegistrationUsingPassword:(NSString *)password;

/**
* This method will attempt to cancel the current user's registration. The user *MUST* be
* already authenticated for this to work successfully.
*
* @see cancelRegistrationSuccessful:
* @see cancelRegistrationFailed:withError:
*/
- (BOOL)cancelRegistration;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - XMPPRegistrationDelegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol XMPPRegistrationDelegate
@optional

/**
* Implement this method when calling [regInstance changePassword:]. It will be invoked
* if the request for changing the user's password is successfully executed and receives a
* successful response.
*
* @param sender XMPPRegistration object invoking this delegate method.
*/
- (void)passwordChangeSuccessful:(XMPPRegistration *)sender;

/**
* Implement this method when calling [regInstance changePassword:]. It will be invoked
* if the request for changing the user's password is unsuccessfully executed or receives
* an unsuccessful response.
*
* @param sender XMPPRegistration object invoking this delegate method.
* @param error NSError containing more details of the failure.
*/
- (void)passwordChangeFailed:(XMPPRegistration *)sender withError:(NSError *)error;

/**
* Implement this method when calling [regInstance cancelRegistration] or a variation. It
* is invoked if the request for canceling the user's registration is successfully
* executed and receives a successful response.
*
* @param sender XMPPRegistration object invoking this delegate method.
*/
- (void)cancelRegistrationSuccessful:(XMPPRegistration *)sender;

/**
* Implement this method when calling [regInstance cancelRegistration] or a variation. It
* is invoked if the request for canceling the user's registration is unsuccessfully
* executed or receives an unsuccessful response.
*
* @param sender XMPPRegistration object invoking this delegate method.
* @param error NSError containing more details of the failure.
*/
- (void)cancelRegistrationFailed:(XMPPRegistration *)sender withError:(NSError *)error;

@end
