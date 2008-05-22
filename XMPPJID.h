#import <Cocoa/Cocoa.h>


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

- (NSString *)bare;
- (NSString *)full;

- (NSUInteger)hash;
- (BOOL)isEqual:(id)anObject;

- (NSString *)description;

@end
