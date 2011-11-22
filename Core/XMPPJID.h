#import <Foundation/Foundation.h>

enum XMPPJIDCompareOptions
{
	XMPPJIDCompareUser     = 1, // 001
	XMPPJIDCompareDomain   = 2, // 010
	XMPPJIDCompareResource = 4, // 100
	
	XMPPJIDCompareBare     = 3, // 011
	XMPPJIDCompareFull     = 7, // 111
};
typedef enum XMPPJIDCompareOptions XMPPJIDCompareOptions;


@interface XMPPJID : NSObject <NSCoding, NSCopying>
{
	__strong NSString *user;
	__strong NSString *domain;
	__strong NSString *resource;
}

+ (XMPPJID *)jidWithString:(NSString *)jidStr;
+ (XMPPJID *)jidWithString:(NSString *)jidStr resource:(NSString *)resource;
+ (XMPPJID *)jidWithUser:(NSString *)user domain:(NSString *)domain resource:(NSString *)resource;

@property (strong, readonly) NSString *user;
@property (strong, readonly) NSString *domain;
@property (strong, readonly) NSString *resource;

- (XMPPJID *)bareJID;
- (XMPPJID *)domainJID;

- (NSString *)bare;
- (NSString *)full;

- (BOOL)isBare;
- (BOOL)isBareWithUser;

- (BOOL)isFull;
- (BOOL)isFullWithUser;

- (BOOL)isServer;

/**
 * When you know both objects are JIDs, this method is a faster way to check equality than isEqual:.
**/
- (BOOL)isEqualToJID:(XMPPJID *)aJID;
- (BOOL)isEqualToJID:(XMPPJID *)aJID options:(XMPPJIDCompareOptions)mask;

@end
