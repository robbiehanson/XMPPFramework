//
//  XMPPLastActivity.h
//  XEP-0012
//
//  Created by Daniel Rodríguez Troitiño on 1/26/2013.
//
//

#import "XMPP.h"

@interface XMPPLastActivity : XMPPModule

@property (atomic, assign) BOOL respondsToQueries;

- (NSString *)sendLastActivityQueryTo:(XMPPJID *)jid;
- (NSString *)sendLastActivityQueryTo:(XMPPJID *)jid withTimeout:(NSTimeInterval)timeout;

@end

@protocol XMPPLastActivityDelegate <NSObject>

- (void)xmppLastActivity:(XMPPLastActivity *)sender didReceiveResponse:(XMPPIQ *)response;
- (void)xmppLastActivity:(XMPPLastActivity *)sender didNotReceiveResponse:(NSString *)queryID dueToTimeout:(NSTimeInterval)timeout;

- (NSUInteger)numberOfIdleTimeSecondsForXMPPLastActivity:(XMPPLastActivity *)sender queryIQ:(XMPPIQ *)iq currentIdleTimeSeconds:(NSUInteger)idleSeconds;

@end
