#import <Cocoa/Cocoa.h>

@class XMPPStream;
@class XMPPMessage;
@protocol XMPPUser;


@interface ChatWindowManager : NSObject

+ (void)openChatWindowWithStream:(XMPPStream *)xmppStream forUser:(id <XMPPUser>)user;

+ (void)handleChatMessage:(XMPPMessage *)message withStream:(XMPPStream *)xmppStream;

@end
