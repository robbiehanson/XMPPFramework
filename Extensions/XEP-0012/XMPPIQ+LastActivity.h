//
//  XMPPIQ+LastActivity.h
//  XEP-0012
//
//  Created by Daniel Rodríguez Troitiño on 1/26/2013.
//

#import <Foundation/Foundation.h>

#import "XMPPIQ.h"

@class XMPPJID;

extern NSString *const XMPPLastActivityNamespace;

@interface XMPPIQ (LastActivity)

+ (instancetype)lastActivityQueryTo:(XMPPJID *)jid;

+ (instancetype)lastActivityResponseTo:(XMPPIQ *)request withSeconds:(NSUInteger)seconds;
+ (instancetype)lastActivityResponseTo:(XMPPIQ *)request withSeconds:(NSUInteger)seconds status:(NSString *)status;

+ (instancetype)lastActivityResponseForbiddenTo:(XMPPIQ *)request;

- (BOOL)isLastActivityQuery;

- (NSUInteger)lastActivitySeconds;

- (NSString *)lastActivityUnavailableStatus;

@end
