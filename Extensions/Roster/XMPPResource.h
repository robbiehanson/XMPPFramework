#import <Foundation/Foundation.h>
#import "XMPP.h"

NS_ASSUME_NONNULL_BEGIN
@protocol XMPPResource
@required

@property (nonatomic, readonly) XMPPJID *jid;
@property (nonatomic, readonly) XMPPPresence *presence;

@property (nonatomic, readonly) NSDate *presenceDate;

- (NSComparisonResult)compare:(id <XMPPResource>)another;

@end
NS_ASSUME_NONNULL_END
