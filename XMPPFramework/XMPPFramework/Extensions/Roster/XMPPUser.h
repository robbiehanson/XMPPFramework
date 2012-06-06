#import <Foundation/Foundation.h>
#import "XMPP.h"

@protocol XMPPResource;


@protocol XMPPUser <NSObject>
@required

- (XMPPJID *)jid;
- (NSString *)nickname;

- (BOOL)isOnline;
- (BOOL)isPendingApproval;

- (id <XMPPResource>)primaryResource;
- (id <XMPPResource>)resourceForJID:(XMPPJID *)jid;

- (NSArray *)allResources;

@end
