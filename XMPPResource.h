#import <Cocoa/Cocoa.h>
@class  XMPPJID;
@class  XMPPUser;
@class  XMPPIQ;
@class  XMPPPresence;


@interface XMPPResource : NSObject
{
	XMPPJID *jid;
	XMPPPresence *presence;
	
	NSDate *presenceReceived;
}

- (id)initWithPresence:(XMPPPresence *)presence;

- (XMPPJID *)jid;
- (XMPPPresence *)presence;

- (NSDate *)presenceReceived;

- (void)updateWithPresence:(XMPPPresence *)presence;

- (NSComparisonResult)compare:(XMPPResource *)another;

@end
