#import <Foundation/Foundation.h>
#import "XMPP.h"

@protocol XMPPResource;

NS_ASSUME_NONNULL_BEGIN
@protocol XMPPUser
@required

@property (nonatomic, readonly) XMPPJID *jid;
@property (nonatomic, readonly) NSString *nickname;

@property (nonatomic, readonly) BOOL isOnline;
@property (nonatomic, readonly) BOOL isPendingApproval;

@property (nonatomic, readonly, nullable) id<XMPPResource> primaryResource;
- (nullable id <XMPPResource>)resourceForJID:(XMPPJID *)jid;

@property (nonatomic, readonly) NSArray<id<XMPPResource>> *allResources;

@end
NS_ASSUME_NONNULL_END
