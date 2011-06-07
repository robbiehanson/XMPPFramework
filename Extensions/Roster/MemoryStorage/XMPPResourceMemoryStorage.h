#import <Foundation/Foundation.h>
#import "XMPPResource.h"

@class XMPPJID;
@class XMPPIQ;
@class XMPPPresence;


@interface XMPPResourceMemoryStorage : NSObject <XMPPResource, NSCopying, NSCoding>
{
	XMPPJID *jid;
	XMPPPresence *presence;
	
	NSDate *presenceDate;
}

// See the XMPPResource protocol for available methods.

@end
