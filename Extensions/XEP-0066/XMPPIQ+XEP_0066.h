#import "XMPPIQ.h"

@interface XMPPIQ (XEP_0066)

+ (XMPPIQ *)outOfBandDataRequestTo:(XMPPJID *)jid
						 elementID:(NSString *)eid
							   URL:(NSURL *)URL
							  desc:(NSString *)dec;

+ (XMPPIQ *)outOfBandDataRequestTo:(XMPPJID *)jid
						 elementID:(NSString *)eid
							   URI:(NSString *)URI
							  desc:(NSString *)dec;


- (id)initOutOfBandDataRequestTo:(XMPPJID *)jid
					   elementID:(NSString *)eid
							 URL:(NSURL *)URL
							desc:(NSString *)dec;

- (id)initOutOfBandDataRequestTo:(XMPPJID *)jid
					   elementID:(NSString *)eid
							 URI:(NSString *)URI
							desc:(NSString *)dec;

- (void)addOutOfBandURL:(NSURL *)URL desc:(NSString *)desc;
- (void)addOutOfBandURI:(NSString *)URI desc:(NSString *)desc;

- (XMPPIQ *)generateOutOfBandDataSuccessResponse;

- (XMPPIQ *)generateOutOfBandDataFailureResponse;

- (XMPPIQ *)generateOutOfBandDataRejectResponse;

- (BOOL)isOutOfBandDataRequest;
- (BOOL)isOutOfBandDataFailureResponse;
- (BOOL)isOutOfBandDataRejectResponse;

- (BOOL)hasOutOfBandData;

- (NSURL *)outOfBandURL;
- (NSString *)outOfBandURI;
- (NSString *)outOfBandDesc;

@end
