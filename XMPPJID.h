#import <Foundation/Foundation.h>
#import "DDXML.h"


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

@end
