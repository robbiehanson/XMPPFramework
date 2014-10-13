//
// Created by Jonathon Staff on 10/11/14.
// Copyright (c) 2014 Jonathon Staff. All rights reserved.
//

#import "XMPPRegistration.h"
#import "XMPPStream.h"
#import "XMPPIDTracker.h"
#import "XMPPIQ.h"
#import "NSXMLElement+XMPP.h"

NSString *const XMPPRegistrationErrorDomain = @"XMPPRegistrationErrorDomain";

@implementation XMPPRegistration

- (void)didActivate
{
  xmppIDTracker = [[XMPPIDTracker alloc] initWithStream:xmppStream dispatchQueue:moduleQueue];
}

- (void)willDeactivate
{
  [xmppIDTracker removeAllIDs];
  xmppIDTracker = nil;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Public API
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)changePassword:(NSString *)newPassword
{
  if (![xmppStream isAuthenticated])
    return NO; // You must be authenticated in order to change your password

  dispatch_block_t block = ^{
      @autoreleasepool {
        NSString *toStr = xmppStream.myJID.domain;
        NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"jabber:iq:register"];

        NSXMLElement *username = [NSXMLElement elementWithName:@"username"
                                                   stringValue:xmppStream.myJID.user];
        NSXMLElement *password = [NSXMLElement elementWithName:@"password"
                                                   stringValue:newPassword];
        [query addChild:username];
        [query addChild:password];

        XMPPIQ *iq = [XMPPIQ iqWithType:@"set"
                                     to:[XMPPJID jidWithString:toStr]
                              elementID:[xmppStream generateUUID]
                                  child:query];

        [xmppIDTracker addID:[iq elementID]
                           target:self
                         selector:@selector(handlePasswordChangeQueryIQ:withInfo:)
                          timeout:60];

        [xmppStream sendElement:iq];
      }
  };

  if (dispatch_get_specific(moduleQueueTag))
    block();
  else
    dispatch_async(moduleQueue, block);

  return YES;
}

- (BOOL)cancelRegistrationUsingPassword:(NSString *)password
{
  // TODO: Handle the scenario of using password

  dispatch_block_t block = ^{
      @autoreleasepool {

        NSXMLElement *remove = [NSXMLElement elementWithName:@"remove"];
        NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"jabber:iq:register"];
        [query addChild:remove];
        XMPPIQ *iq = [XMPPIQ iqWithType:@"set"
                              elementID:[xmppStream generateUUID]
                                  child:query];

        [xmppIDTracker addElement:iq
                           target:self
                         selector:@selector(handleRegistrationCancelQueryIQ:withInfo:)
                          timeout:60];

        [xmppStream sendElement:iq];
      }
  };

  if (dispatch_get_specific(moduleQueueTag))
    block();
  else
    dispatch_async(moduleQueue, block);

  return YES;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - XMPPIDTracker
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)handlePasswordChangeQueryIQ:(XMPPIQ *)iq withInfo:(XMPPBasicTrackingInfo *)info
{
  dispatch_block_t block = ^{
      @autoreleasepool {
        NSXMLElement *errorElem = [iq elementForName:@"error"];

        if (errorElem) {
          NSString *errMsg = [[errorElem children] componentsJoinedByString:@", "];
          NSInteger errCode = [errorElem attributeIntegerValueForName:@"code"
                                                     withDefaultValue:-1];
          NSDictionary *errInfo = @{NSLocalizedDescriptionKey : errMsg};
          NSError *err = [NSError errorWithDomain:XMPPRegistrationErrorDomain
                                             code:errCode
                                         userInfo:errInfo];

          [multicastDelegate passwordChangeFailed:self
                                        withError:err];
          return;
        }

        NSString *type = [iq type];

        if ([type isEqualToString:@"result"] && iq.childCount == 0) {
          [multicastDelegate passwordChangeSuccessful:self];
        } else {
          // this should be impossible to reach, but just for safety's sake...
          [multicastDelegate passwordChangeFailed:self
                                        withError:nil];
        }
      }
  };

  if (dispatch_get_specific(moduleQueueTag))
    block();
  else
    dispatch_async(moduleQueue, block);
}

- (void)handleRegistrationCancelQueryIQ:(XMPPIQ *)iq withInfo:(XMPPBasicTrackingInfo *)info
{
  dispatch_block_t block = ^{
      @autoreleasepool {
        NSXMLElement *errorElem = [iq elementForName:@"error"];

        if (errorElem) {
          NSString *errMsg = [[errorElem children] componentsJoinedByString:@", "];
          NSInteger errCode = [errorElem attributeIntegerValueForName:@"code"
                                                     withDefaultValue:-1];
          NSDictionary *errInfo = @{NSLocalizedDescriptionKey : errMsg};
          NSError *err = [NSError errorWithDomain:XMPPRegistrationErrorDomain
                                             code:errCode
                                         userInfo:errInfo];

          [multicastDelegate cancelRegistrationFailed:self
                                            withError:err];
          return;
        }

        NSString *type = [iq type];

        if ([type isEqualToString:@"result"] && iq.childCount == 0) {
          [multicastDelegate cancelRegistrationSuccessful:self];
        } else {
          // this should be impossible to reach, but just for safety's sake...
          [multicastDelegate cancelRegistrationFailed:self
                                            withError:nil];
        }
      }
  };

  if (dispatch_get_specific(moduleQueueTag))
    block();
  else
    dispatch_async(moduleQueue, block);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - XMPPStreamDelegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)xmppStream:(XMPPStream *)stream didReceiveIQ:(XMPPIQ *)iq
{
  NSString *type = [iq type];

  if ([type isEqualToString:@"result"] || [type isEqualToString:@"error"]) {
    NSLog(@"invoking with iq: %@", iq);
    return [xmppIDTracker invokeForElement:iq withObject:iq];
  }

  return NO;
}

@end