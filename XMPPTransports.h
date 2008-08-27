#import <Foundation/Foundation.h>

@class XMPPClient;

@interface XMPPTransports : NSObject
{
@private
	XMPPClient *client;
}

- (id)initWithXMPPClient:(XMPPClient *)xmppClient;

- (XMPPClient *)xmppClient;

- (void)queryGatewayDiscoveryIdentityForLegacyService:(NSString *)service;
- (void)queryGatewayAgentInfo;
- (void)queryRegistrationRequirementsForLegacyService:(NSString *)service;
- (void)registerLegacyService:(NSString *)service userName:(NSString *)userName password:(NSString *)password;
- (void)unregisterLegacyService:(NSString *)service;

@end
