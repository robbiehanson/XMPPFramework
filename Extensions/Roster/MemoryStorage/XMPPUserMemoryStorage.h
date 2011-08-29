#import <Foundation/Foundation.h>
#import "XMPPUser.h"
#import "XMPP.h"

#if !TARGET_OS_IPHONE
  #import <Cocoa/Cocoa.h>
#endif

@class XMPPResourceMemoryStorage;


@interface XMPPUserMemoryStorage : NSObject <XMPPUser, NSCopying, NSCoding>
{
	XMPPJID *jid;
	NSMutableDictionary *itemAttributes;
	
	NSMutableDictionary *resources;
	XMPPResourceMemoryStorage *primaryResource;
	
#if TARGET_OS_IPHONE
	UIImage *photo;
#else
	NSImage *photo;
#endif
}

/*	From the XMPPUser protocol
	
- (XMPPJID *)jid;
- (NSString *)nickname;

- (BOOL)isOnline;
- (BOOL)isPendingApproval;

- (id <XMPPResource>)primaryResource;
- (id <XMPPResource>)resourceForJID:(XMPPJID *)jid;

- (NSArray *)allResources;

*/

/**
 * Simple convenience method.
 * If a nickname exists for the user, the nickname is returned.
 * Otherwise the jid is returned (as a string).
**/
- (NSString *)displayName;

/**
 * If XMPPvCardAvatarModule is included in the framework, the XMPPRoster will automatically integrate with it,
 * and we'll save the the user photos after they've been downloaded.
**/
#if TARGET_OS_IPHONE
@property (nonatomic, retain, readonly) UIImage *photo;
#else
@property (nonatomic, retain, readonly) NSImage *photo;
#endif

/**
 * 
**/

- (NSComparisonResult)compareByName:(XMPPUserMemoryStorage *)another;
- (NSComparisonResult)compareByName:(XMPPUserMemoryStorage *)another options:(NSStringCompareOptions)mask;

- (NSComparisonResult)compareByAvailabilityName:(XMPPUserMemoryStorage *)another;
- (NSComparisonResult)compareByAvailabilityName:(XMPPUserMemoryStorage *)another options:(NSStringCompareOptions)mask;

@end
