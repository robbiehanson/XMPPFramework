#import <Foundation/Foundation.h>

#define _XMPP_TRANSPORTS_H

@class XMPPStream;


@interface XMPPTransports : NSObject
{
	XMPPStream *xmppStream;
}

- (id)initWithStream:(XMPPStream *)xmppStream;

@property (nonatomic, strong, readonly) XMPPStream *xmppStream;

- (void)queryGatewayDiscoveryIdentityForLegacyService:(NSString *)service;
- (void)queryGatewayAgentInfo;
- (void)queryRegistrationRequirementsForLegacyService:(NSString *)service;
- (void)registerLegacyService:(NSString *)service username:(NSString *)username password:(NSString *)password;
- (void)unregisterLegacyService:(NSString *)service;

@end
