#import <Cocoa/Cocoa.h>
@class   XMPPStream;
@class   XMPPUser;

@interface ChatWindowManager : NSObject

+ (void)openChatWindowWithXMPPStream:(XMPPStream *)stream forXMPPUser:(XMPPUser *)user;

+ (void)handleChatMessage:(NSXMLElement *)message withXMPPStream:(XMPPStream *)stream fromXMPPUser:(XMPPUser *)user;

@end
