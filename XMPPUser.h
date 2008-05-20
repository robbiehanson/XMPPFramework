#import <Cocoa/Cocoa.h>
@class  XMPPJID;
@class  XMPPIQ;
@class  XMPPPresence;
@class  XMPPResource;


@interface XMPPUser : NSObject
{
	NSMutableDictionary *resources;
	
	XMPPJID *jid;
	
	NSMutableDictionary *itemAttributes;
	XMPPResource *primaryResource;
}

- (id)initWithItem:(NSXMLElement *)item;

- (XMPPJID *)jid;
- (NSString *)nickname;

- (NSString *)displayName;

- (BOOL)isOnline;
- (BOOL)isPendingApproval;

- (XMPPResource *)primaryResource;
- (NSArray *)sortedResources;

- (void)updateWithItem:(NSXMLElement *)item;
- (void)updateWithPresence:(XMPPPresence *)presence;

- (NSComparisonResult)compareByName:(XMPPUser *)another;
- (NSComparisonResult)compareByName:(XMPPUser *)another options:(NSStringCompareOptions)mask;

- (NSComparisonResult)compareByAvailabilityName:(XMPPUser *)another;
- (NSComparisonResult)compareByAvailabilityName:(XMPPUser *)another options:(NSStringCompareOptions)mask;

@end
