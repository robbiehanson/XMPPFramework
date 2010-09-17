#import <Foundation/Foundation.h>
#import "XMPPResource.h"

@class XMPPJID;
@class XMPPIQ;
@class XMPPPresence;


@interface XMPPResourceMemoryStorage : NSObject <XMPPResource, NSCoding>
{
	XMPPJID *jid;
	XMPPPresence *presence;
	
	NSDate *presenceDate;
}

- (id)initWithPresence:(XMPPPresence *)aPresence;

- (void)updateWithPresence:(XMPPPresence *)presence;

- (XMPPPresence *)presence;

@end
