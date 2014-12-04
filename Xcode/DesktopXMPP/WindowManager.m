#import "WindowManager.h"
#import "ChatController.h"
#import "MucController.h"
#import "DDLog.h"

// Log levels: off, error, warn, info, verbose
static const int ddLogLevel = LOG_LEVEL_VERBOSE;

#pragma unused(ddLogLevel)


@implementation WindowManager

static NSMutableArray *chatControllers;
static NSMutableArray *mucControllers;

+ (void)initialize
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		
		chatControllers = [[NSMutableArray alloc] init];
		mucControllers  = [[NSMutableArray alloc] init];
	});
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark ChatController
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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
		// Create chat controller
		XMPPJID *jid;
		
		id <XMPPResource> primaryResource = [user primaryResource];
		if (primaryResource)
			jid = [primaryResource jid];
		else
			jid = [user jid];
		
		chatController = [[ChatController alloc] initWithStream:xmppStream jid:jid];
		[chatController showWindow:self];
		
		[chatControllers addObject:chatController];
	}
}

+ (void)closeChatWindow:(ChatController *)chatController
{
	[chatControllers removeObject:chatController];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark MucController
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (MucController *)mucControllerForJID:(XMPPJID *)jid
{
	// Loop through all the open controllers, and see if any of them are the one we want...
	
	for (MucController *mucController in mucControllers)
	{
		XMPPJID *currentJID = [mucController jid];
		
		if ([currentJID isEqualToJID:jid])
		{
			return mucController;
		}
	}
	
	return nil;
}

+ (void)openMucWindowWithStream:(XMPPStream *)xmppStream forRoom:(XMPPJID *)roomJid
{
	MucController *mucController = [self mucControllerForJID:roomJid];
	
	if (mucController)
	{
		[[mucController window] makeKeyAndOrderFront:self];
	}
	else
	{
		// Create muc controller
		mucController = [[MucController alloc] initWithStream:xmppStream roomJID:roomJid];
		[mucController showWindow:self];
		
		[mucControllers addObject:mucController];
	}
}

+ (void)closeMucWindow:(MucController *)mucController
{
	[mucControllers removeObject:mucController];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark HandleMessage
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (void)handleMessage:(XMPPMessage *)message withStream:(XMPPStream *)xmppStream
{
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
