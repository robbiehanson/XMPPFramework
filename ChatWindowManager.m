#import "ChatWindowManager.h"
#import "ChatController.h"
#import "XMPPStream.h"
#import "XMPPUser.h"

@implementation ChatWindowManager

+ (ChatController *)chatControllerForXMPPUser:(XMPPUser *)user
{
	// Loop through all the open windows, and see if any of them are the one we want...
	NSArray *windows = [NSApp windows];
	
	int i;
	for(i = 0; i < [windows count]; i++)
	{
		NSWindow *currentWindow = [windows objectAtIndex:i];
		ChatController *currentWC = [currentWindow windowController];
		
		if([currentWC isKindOfClass:[ChatController class]] && [[currentWC xmppUser] isEqual:user])
		{
			return currentWC;
		}
	}
	
	return nil;
}

+ (void)openChatWindowWithXMPPStream:(XMPPStream *)stream forXMPPUser:(XMPPUser *)user
{
	ChatController *cc = [[self class] chatControllerForXMPPUser:user];
	
	if(cc)
	{
		[[cc window] makeKeyAndOrderFront:self];
	}
	else
	{
		// Create Manual Sync Window
		ChatController *temp = [[ChatController alloc] initWithXMPPStream:stream forXMPPUser:user];
		[temp showWindow:self];
		
		// Note: MSWController will automatically release itself when the user closes the window
	}
}

+ (void)handleChatMessage:(NSXMLElement *)message withXMPPStream:(XMPPStream *)stream fromXMPPUser:(XMPPUser *)user
{
	ChatController *cc = [[self class] chatControllerForXMPPUser:user];
	
	if(cc)
	{
		[cc receiveMessage:message];
	}
	else
	{
		// Create new chat window
		ChatController *newCC = [[ChatController alloc] initWithXMPPStream:stream forXMPPUser:user];
		[newCC showWindow:self];
		
		// Note: ChatController will automatically release itself when the user closes the window
		
		[newCC receiveMessage:message];
	}
}

@end
