#import <Foundation/Foundation.h>

#define _XMPP_TRANSPORTS_H

@class XMPPStream;

NS_ASSUME_NONNULL_BEGIN
@interface XMPPTransports : NSObject

- (instancetype)initWithStream:(XMPPStream *)xmppStream;

@property (nonatomic, strong, readonly) XMPPStream *xmppStream;

- (void)queryGatewayDiscoveryIdentityForLegacyService:(NSString *)service;
- (void)queryGatewayAgentInfo;
- (void)queryRegistrationRequirementsForLegacyService:(NSString *)service;
- (void)registerLegacyService:(NSString *)service username:(NSString *)username password:(NSString *)password;
- (void)unregisterLegacyService:(NSString *)service;

@end
NS_ASSUME_NONNULL_END
