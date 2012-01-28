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

/* From the XMPPResource protocol

- (XMPPJID *)jid;
- (XMPPPresence *)presence;

- (NSDate *)presenceDate;

- (NSComparisonResult)compare:(id <XMPPResource>)another;

*/

@end
