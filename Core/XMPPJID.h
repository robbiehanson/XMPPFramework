#import <Foundation/Foundation.h>


@interface XMPPJID : NSObject <NSCoding, NSCopying>
{
	NSString *user;
	NSString *domain;
	NSString *resource;
}

+ (XMPPJID *)jidWithString:(NSString *)jidStr;
+ (XMPPJID *)jidWithString:(NSString *)jidStr resource:(NSString *)resource;
+ (XMPPJID *)jidWithUser:(NSString *)user domain:(NSString *)domain resource:(NSString *)resource;

- (NSString *)user;
- (NSString *)domain;
- (NSString *)resource;

- (XMPPJID *)bareJID;
- (XMPPJID *)domainJID;

- (NSString *)bare;
- (NSString *)full;

- (BOOL)isBare;
- (BOOL)isBareWithUser;

- (BOOL)isFull;
- (BOOL)isFullWithUser;

- (BOOL)isServer;

@end
