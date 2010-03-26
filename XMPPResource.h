#import <Foundation/Foundation.h>

@class XMPPJID;
@class XMPPIQ;
@class XMPPPresence;


@protocol XMPPResource

- (XMPPJID *)jid;
- (XMPPPresence *)presence;

- (NSDate *)presenceDate;

- (NSComparisonResult)compare:(id <XMPPResource>)another;

@end
