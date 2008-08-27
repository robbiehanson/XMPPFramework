#import "ChatController.h"
#import "XMPP.h"


@implementation ChatController

- (id)initWithXMPPClient:(XMPPClient *)client jid:(XMPPJID *)fullJID
{
	if(self = [super initWithWindowNibName:@"ChatWindow"])
	{
		xmppClient = [client retain];
		jid = [fullJID retain];
	}
	return self;
}

- (void)awakeFromNib
{
	[xmppClient addDelegate:self];
	
	[messageView setString:@""];
	
	[[self window] setTitle:[jid full]];
	[[self window] makeFirstResponder:messageField];
}

/**
 * Called immediately before the window closes.
 * 
 * This method's job is to release the WindowController (self)
 * This is so that the nib file is released from memory.
**/
- (void)windowWillClose:(NSNotification *)aNotification
{
	NSLog(@"ChatController: windowWillClose");
	
	[xmppClient removeDelegate:self];
	[self autorelease];
}

- (void)dealloc
{
	NSLog(@"Destroying self: %@", self);
	
	[xmppClient release];
	[jid release];
	[super dealloc];
}

- (XMPPJID *)jid
{
	return jid;
}

- (void)scrollToBottom
{
	NSScrollView *scrollView = [messageView enclosingScrollView];
	NSPoint newScrollOrigin;
	
	if ([[scrollView documentView] isFlipped])
		newScrollOrigin = NSMakePoint(0.0, NSMaxY([[scrollView documentView] frame]));
	else
		newScrollOrigin = NSMakePoint(0.0, 0.0);
	
	[[scrollView documentView] scrollPoint:newScrollOrigin];
}

- (void)xmppClientDidAuthenticate:(XMPPClient *)sender
{
	[messageField setEnabled:YES];
}

- (void)xmppClient:(XMPPClient *)sender didReceiveMessage:(XMPPMessage *)message
{
	if(![jid isEqual:[message from]]) return;
	
	if([message isChatMessageWithBody])
	{
		NSString *messageStr = [[message elementForName:@"body"] stringValue];
		
		NSString *paragraph = [NSString stringWithFormat:@"%@\n\n", messageStr];
		
		NSMutableParagraphStyle *mps = [[[NSMutableParagraphStyle alloc] init] autorelease];
		[mps setAlignment:NSLeftTextAlignment];
		
		NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithCapacity:2];
		[attributes setObject:mps forKey:NSParagraphStyleAttributeName];
		[attributes setObject:[NSColor colorWithCalibratedRed:250 green:250 blue:250 alpha:1] forKey:NSBackgroundColorAttributeName];
		
		NSAttributedString *as = [[NSAttributedString alloc] initWithString:paragraph attributes:attributes];
		[as autorelease];
		
		[[messageView textStorage] appendAttributedString:as];
	}
}

- (void)xmppClientDidDisconnect:(XMPPClient *)sender
{
	[messageField setEnabled:NO];
}

- (IBAction)sendMessage:(id)sender
{
	NSString *messageStr = [messageField stringValue];
	
	if([messageStr length] > 0)
	{
		NSXMLElement *body = [NSXMLElement elementWithName:@"body"];
		[body setStringValue:messageStr];
		
		NSXMLElement *message = [NSXMLElement elementWithName:@"message"];
		[message addAttributeWithName:@"type" stringValue:@"chat"];
		[message addAttributeWithName:@"to" stringValue:[jid full]];
		[message addChild:body];
		
		[xmppClient sendElement:message];
		
		NSString *paragraph = [NSString stringWithFormat:@"%@\n\n", messageStr];
		
		NSMutableParagraphStyle *mps = [[[NSMutableParagraphStyle alloc] init] autorelease];
		[mps setAlignment:NSRightTextAlignment];
		
		NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithCapacity:2];
		[attributes setObject:mps forKey:NSParagraphStyleAttributeName];
		
		NSAttributedString *as = [[NSAttributedString alloc] initWithString:paragraph attributes:attributes];
		[as autorelease];
		
		[[messageView textStorage] appendAttributedString:as];
		
		[self scrollToBottom];
		
		[messageField setStringValue:@""];
		[[self window] makeFirstResponder:messageField];
	}
}

@end
