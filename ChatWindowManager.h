#import <Cocoa/Cocoa.h>
@class   XMPPClient;
@class   XMPPUser;
@class   XMPPMessage;


@interface ChatWindowManager : NSObject

+ (void)openChatWindowWithXMPPClient:(XMPPClient *)xc forXMPPUser:(XMPPUser *)user;

+ (void)handleChatMessage:(XMPPMessage *)message withXMPPClient:(XMPPClient *)client;

@end
