#import <Foundation/Foundation.h>

#if !TARGET_OS_IPHONE
  #import <Cocoa/Cocoa.h>
#endif

#if TARGET_OS_IPHONE
  #import "DDXML.h"
#endif

@class XMPPJID;
@class XMPPIQ;
@class XMPPPresence;
@protocol XMPPResource;


@protocol XMPPUser <NSObject>

#if TARGET_OS_IPHONE
@property (nonatomic, retain) UIImage * photo;
#else
@property (nonatomic, retain) NSImage * photo;
#endif

- (XMPPJID *)jid;
- (NSString *)nickname;

- (NSString *)displayName;

- (BOOL)isOnline;
- (BOOL)isPendingApproval;

- (id <XMPPResource>)primaryResource;
- (id <XMPPResource>)resourceForJID:(XMPPJID *)jid;

- (NSArray *)sortedResources;
- (NSArray *)unsortedResources;

- (NSComparisonResult)compareByName:(id <XMPPUser>)another;
- (NSComparisonResult)compareByName:(id <XMPPUser>)another options:(NSStringCompareOptions)mask;

- (NSComparisonResult)compareByAvailabilityName:(id <XMPPUser>)another;
- (NSComparisonResult)compareByAvailabilityName:(id <XMPPUser>)another options:(NSStringCompareOptions)mask;

@end
