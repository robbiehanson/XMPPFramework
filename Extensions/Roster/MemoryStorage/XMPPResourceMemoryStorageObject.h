#import <Foundation/Foundation.h>
#import "XMPPResource.h"

@class XMPPJID;
@class XMPPIQ;
@class XMPPPresence;


@interface XMPPResourceMemoryStorageObject : NSObject <XMPPResource, NSCopying, NSSecureCoding>
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
