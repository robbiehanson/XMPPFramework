#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface NSData (XMPP)

@property (nonatomic, readonly) NSData *xmpp_md5Digest;

@property (nonatomic, readonly) NSData *xmpp_sha1Digest;

@property (nonatomic, readonly) NSString *xmpp_hexStringValue;

@property (nonatomic, readonly) NSString *xmpp_base64Encoded;
@property (nonatomic, readonly) NSData *xmpp_base64Decoded;

@property (nonatomic, readonly) BOOL xmpp_isJPEG;
@property (nonatomic, readonly) BOOL xmpp_isPNG;
@property (nonatomic, readonly, nullable) NSString *xmpp_imageType;

@end

#ifndef XMPP_EXCLUDE_DEPRECATED

#define XMPP_DEPRECATED($message) __attribute__((deprecated($message)))

@interface NSData (XMPPDeprecated)
- (NSData *)md5Digest XMPP_DEPRECATED("Use -xmpp_md5Digest");
- (NSData *)sha1Digest XMPP_DEPRECATED("Use -xmpp_sha1Digest");
- (NSString *)hexStringValue XMPP_DEPRECATED("Use -xmpp_hexStringValue");
- (NSString *)base64Encoded XMPP_DEPRECATED("Use -xmpp_base64Encoded");
- (NSData *)base64Decoded XMPP_DEPRECATED("Use -xmpp_base64Decoded");
@end

#undef XMPP_DEPRECATED

#endif
NS_ASSUME_NONNULL_END
