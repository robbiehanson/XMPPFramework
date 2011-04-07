#import <Foundation/Foundation.h>
#import "XMPPUser.h"

#if TARGET_OS_IPHONE
  #import "DDXML.h"
#endif

@class XMPPJID;
@class XMPPPresence;
@class XMPPResourceMemoryStorage;


@interface XMPPUserMemoryStorage : NSObject <XMPPUser, NSCopying, NSCoding>
{
	XMPPJID *jid;
	NSMutableDictionary *itemAttributes;
	
#if TARGET_OS_IPHONE
	UIImage *photo;
#else
	NSImage *photo;
#endif
	
	NSMutableDictionary *resources;
	XMPPResourceMemoryStorage *primaryResource;
	
	NSInteger tag;
}

// See the XMPPUser protocol for available methods.

@end
