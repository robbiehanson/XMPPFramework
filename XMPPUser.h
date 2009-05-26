#import <Foundation/Foundation.h>
#import "DDXML.h"

@class XMPPJID;
@class XMPPIQ;
@class XMPPPresence;
@class XMPPResource;

#if MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_4
  #define NSStringCompareOptions unsigned
#endif


@interface XMPPUser : NSObject <NSCoding>
{
	XMPPJID *jid;
	NSMutableDictionary *itemAttributes;
	
	NSMutableDictionary *resources;
	XMPPResource *primaryResource;
	
#if MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_4
	int tag;
#else
	NSInteger tag;
#endif
}

- (id)initWithJID:(XMPPJID *)jid;
- (id)initWithItem:(NSXMLElement *)item;

- (XMPPJID *)jid;
- (NSString *)nickname;

- (NSString *)displayName;

- (BOOL)isOnline;
- (BOOL)isPendingApproval;

- (XMPPResource *)primaryResource;
- (XMPPResource *)resourceForJID:(XMPPJID *)jid;
- (NSArray *)sortedResources;
- (NSArray *)unsortedResources;

- (void)updateWithItem:(NSXMLElement *)item;
- (void)updateWithPresence:(XMPPPresence *)presence;

- (NSComparisonResult)compareByName:(XMPPUser *)another;
- (NSComparisonResult)compareByName:(XMPPUser *)another options:(NSStringCompareOptions)mask;

- (NSComparisonResult)compareByAvailabilityName:(XMPPUser *)another;
- (NSComparisonResult)compareByAvailabilityName:(XMPPUser *)another options:(NSStringCompareOptions)mask;

#if MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_4
- (int)tag;
- (void)setTag:(int)anInt;
#else
- (NSInteger)tag;
- (void)setTag:(NSInteger)anInt;
#endif

@end
