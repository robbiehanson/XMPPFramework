#import "ChatWindowManager.h"
#import "ChatController.h"
#import "XMPP.h"


@implementation ChatWindowManager

+ (ChatController *)chatControllerForJID:(XMPPJID *)jid matchResource:(BOOL)matchResource
{
	// Loop through all the open windows, and see if any of them are the one we want...
	NSArray *windows = [NSApp windows];

	int i;
	for(i = 0; i < [windows count]; i++)
	{
		NSWindow *currentWindow = [windows objectAtIndex:i];
		ChatController *currentWC = [currentWindow windowController];
		
		if([currentWC isKindOfClass:[ChatController class]])
		{
			if(matchResource)
			{
				XMPPJID *currentJID = [currentWC jid];
				
				if([currentJID isEqual:jid])
				{
					return currentWC;
				}
			}
			else
			{
				XMPPJID *currentJID = [[currentWC jid] bareJID];
				
				if([currentJID isEqual:[jid bareJID]])
				{
					return currentWC;
				}
			}
		}
	}
	
	return nil;
}

+ (void)openChatWindowWithXMPPClient:(XMPPClient *)client forXMPPUser:(XMPPUser *)user
{
	ChatController *cc = [[self class] chatControllerForJID:[user jid] matchResource:NO];
	
	if(cc)
	{
		[[cc window] makeKeyAndOrderFront:self];
	}
	else
	{
		// Create Manual Sync Window
		XMPPJID *jid = [[user primaryResource] jid];
		
		ChatController *temp = [[ChatController alloc] initWithXMPPClient:client jid:jid];
		[temp showWindow:self];
		
		// Note: ChatController will automatically release itself when the user closes the window
	}
}

+ (void)handleChatMessage:(XMPPMessage *)message withXMPPClient:(XMPPClient *)client
{
	NSLog(@"ChatWindowManager: handleChatMessage");
	
	ChatController *cc = [[self class] chatControllerForJID:[message from] matchResource:YES];
	
	if(!cc)
	{
		// Create new chat window
		XMPPJID *jid = [message from];
		
		ChatController *newCC = [[ChatController alloc] initWithXMPPClient:client jid:jid message:message];
		[newCC showWindow:self];
		
		// Note: ChatController will automatically release itself when the user closes the window.
	}
}

@end
