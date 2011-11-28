#import "ChatWindowManager.h"
#import "ChatController.h"
#import "XMPP.h"
#import "XMPPRoster.h"


@implementation ChatWindowManager

static NSMutableArray *chatControllers;

+ (void)initialize
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		
		chatControllers = [[NSMutableArray alloc] init];
	});
}

+ (ChatController *)chatControllerForJID:(XMPPJID *)jid matchResource:(BOOL)matchResource
{
	// Loop through all the open chat windows, and see if any of them are the one we want...

	XMPPJIDCompareOptions options = matchResource ? XMPPJIDCompareFull : XMPPJIDCompareBare;
	
	for (ChatController *chatController in chatControllers)
	{
		XMPPJID *currentJID = [chatController jid];
		
		if ([currentJID isEqualToJID:jid options:options])
		{
			return chatController;
		}
	}
	
	return nil;
}

+ (void)openChatWindowWithStream:(XMPPStream *)xmppStream forUser:(id <XMPPUser>)user
{
	ChatController *chatController = [self chatControllerForJID:[user jid] matchResource:NO];
	
	if (chatController)
	{
		[[chatController window] makeKeyAndOrderFront:self];
	}
	else
	{
		// Create Manual Sync Window
		XMPPJID *jid = [[user primaryResource] jid];
		
		chatController = [[ChatController alloc] initWithStream:xmppStream jid:jid];
		[chatController showWindow:self];
		
		[chatControllers addObject:chatController];
	}
}

+ (void)closeChatWindow:(ChatController *)chatController
{
	[chatControllers removeObject:chatController];
}

+ (void)handleChatMessage:(XMPPMessage *)message withStream:(XMPPStream *)xmppStream
{
	NSLog(@"ChatWindowManager: handleChatMessage");
	
	ChatController *chatController = [self chatControllerForJID:[message from] matchResource:YES];
	
	if (chatController == nil)
	{
		// Create new chat window
		XMPPJID *jid = [message from];
		
		chatController = [[ChatController alloc] initWithStream:xmppStream jid:jid message:message];
		[chatController showWindow:self];
		
		[chatControllers addObject:chatController];
	}
}

@end
