#import <Cocoa/Cocoa.h>
#import "XMPPFramework.h"

@class ChatController;
@class MucController;


@interface WindowManager : NSObject

+ (void)openChatWindowWithStream:(XMPPStream *)xmppStream forUser:(id <XMPPUser>)user;
+ (void)closeChatWindow:(ChatController *)cc;

+ (void)openMucWindowWithStream:(XMPPStream *)xmppStream forRoom:(XMPPJID *)roomJid;
+ (void)closeMucWindow:(MucController *)mc;

+ (void)handleMessage:(XMPPMessage *)message withStream:(XMPPStream *)xmppStream;

@end
