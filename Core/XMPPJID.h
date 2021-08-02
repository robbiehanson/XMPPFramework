#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, XMPPJIDCompare) {
    XMPPJIDCompareUser     = 1, // 001
    XMPPJIDCompareDomain   = 2, // 010
    XMPPJIDCompareResource = 4, // 100
    
    XMPPJIDCompareBare     = 3, // 011
    XMPPJIDCompareFull     = 7, // 111
};
typedef XMPPJIDCompare XMPPJIDCompareOptions; // for backwards compatibility

NS_ASSUME_NONNULL_BEGIN

@interface XMPPJID : NSObject <NSSecureCoding, NSCopying>

+ (nullable XMPPJID *)jidWithString:(NSString *)jidStr;
+ (nullable XMPPJID *)jidWithString:(NSString *)jidStr resource:(nullable NSString *)resource;
+ (nullable XMPPJID *)jidWithUser:(nullable NSString *)user domain:(NSString *)domain resource:(nullable NSString *)resource;

@property (nonatomic, nullable, copy, readonly) NSString *user;
@property (nonatomic, copy, readonly) NSString *domain;
@property (nonatomic, nullable, copy, readonly) NSString *resource;

/**
 * Terminology (from RFC 6120):
 * 
 * The term "bare JID" refers to an XMPP address of the form <localpart@domainpart> (for an account at a server)
 * or of the form <domainpart> (for a server).
 * 
 * The term "full JID" refers to an XMPP address of the form
 * <localpart@domainpart/resourcepart> (for a particular authorized client or device associated with an account)
 * or of the form <domainpart/resourcepart> (for a particular resource or script associated with a server).
 * 
 * Thus a bareJID is one that does not have a resource.
 * And a fullJID is one that does have a resource.
 * 
 * For convenience, there are also methods that that check for a user component as well.
**/

@property (nonatomic, readonly) XMPPJID *bareJID NS_SWIFT_NAME(bareJID);
@property (nonatomic, readonly) XMPPJID *domainJID NS_SWIFT_NAME(domainJID);

@property (nonatomic, readonly) NSString *bare;
@property (nonatomic, readonly) NSString *full;

@property (nonatomic, readonly) BOOL isBare;
@property (nonatomic, readonly) BOOL isBareWithUser;

@property (nonatomic, readonly) BOOL isFull;
@property (nonatomic, readonly) BOOL isFullWithUser;

/**
 * A server JID does not have a user component.
**/
@property (nonatomic, readonly) BOOL isServer;

/**
 * Returns a new jid with the given resource.
**/
- (XMPPJID *)jidWithNewResource:(NSString *)resource;

/**
 * When you know both objects are JIDs, this method is a faster way to check equality than isEqual:.
**/
- (BOOL)isEqualToJID:(XMPPJID *)aJID;
- (BOOL)isEqualToJID:(XMPPJID *)aJID options:(XMPPJIDCompareOptions)mask;

@end

NS_ASSUME_NONNULL_END
