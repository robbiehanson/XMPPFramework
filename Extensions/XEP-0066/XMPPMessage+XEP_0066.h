#import "XMPPMessage.h"

NS_ASSUME_NONNULL_BEGIN
@interface XMPPMessage (XEP_0066)

- (void)addOutOfBandURL:(NSURL *)URL desc:(nullable NSString *)desc;
- (void)addOutOfBandURI:(NSString *)URI desc:(nullable NSString *)desc;

@property (nonatomic, readonly) BOOL hasOutOfBandData;

@property (nonatomic, readonly, nullable) NSURL *outOfBandURL;
@property (nonatomic, readonly, nullable) NSString *outOfBandURI;
@property (nonatomic, readonly, nullable) NSString *outOfBandDesc;

@end
NS_ASSUME_NONNULL_END
