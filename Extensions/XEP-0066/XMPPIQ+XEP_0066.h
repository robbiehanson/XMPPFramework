#import "XMPPIQ.h"

NS_ASSUME_NONNULL_BEGIN
@interface XMPPIQ (XEP_0066)

+ (XMPPIQ *)outOfBandDataRequestTo:(XMPPJID *)jid
						 elementID:(NSString *)eid
							   URL:(NSURL *)URL
							  desc:(nullable NSString *)dec;

+ (XMPPIQ *)outOfBandDataRequestTo:(XMPPJID *)jid
						 elementID:(NSString *)eid
							   URI:(NSString *)URI
							  desc:(nullable NSString *)dec;


- (instancetype)initOutOfBandDataRequestTo:(XMPPJID *)jid
                                 elementID:(NSString *)eid
                                       URL:(NSURL *)URL
                                      desc:(nullable NSString *)dec;

- (instancetype)initOutOfBandDataRequestTo:(XMPPJID *)jid
                                 elementID:(NSString *)eid
                                       URI:(NSString *)URI
                                      desc:(nullable NSString *)dec;

- (void)addOutOfBandURL:(NSURL *)URL desc:(nullable NSString *)desc;
- (void)addOutOfBandURI:(NSString *)URI desc:(nullable NSString *)desc;

- (XMPPIQ *)generateOutOfBandDataSuccessResponse;

- (XMPPIQ *)generateOutOfBandDataFailureResponse;

- (XMPPIQ *)generateOutOfBandDataRejectResponse;

@property (nonatomic, readonly) BOOL isOutOfBandDataRequest;
@property (nonatomic, readonly) BOOL isOutOfBandDataFailureResponse;
@property (nonatomic, readonly) BOOL isOutOfBandDataRejectResponse;

@property (nonatomic, readonly) BOOL hasOutOfBandData;

@property (nonatomic, readonly, nullable) NSURL *outOfBandURL;
@property (nonatomic, readonly, nullable) NSString *outOfBandURI;
@property (nonatomic, readonly, nullable) NSString *outOfBandDesc;

@end
NS_ASSUME_NONNULL_END
