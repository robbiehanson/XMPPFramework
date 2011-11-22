#import <Cocoa/Cocoa.h>

@class XMPPStream;
@class XMPPMessage;
@class ChatController;
@protocol XMPPUser;


@interface ChatWindowManager : NSObject

+ (void)openChatWindowWithStream:(XMPPStream *)xmppStream forUser:(id <XMPPUser>)user;
+ (void)closeChatWindow:(ChatController *)cc;

+ (void)handleChatMessage:(XMPPMessage *)message withStream:(XMPPStream *)xmppStream;

@end
