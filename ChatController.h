#import <Cocoa/Cocoa.h>
@class   XMPPStream;
@class   XMPPUser;

@interface ChatController : NSWindowController
{
	XMPPStream *xmppStream;
	XMPPUser *xmppUser;
	
    IBOutlet id messageField;
    IBOutlet id messageView;
}

- (id)initWithXMPPStream:(XMPPStream *)stream forXMPPUser:(XMPPUser *)user;

- (XMPPUser *)xmppUser;
- (void)receiveMessage:(NSXMLElement *)message;

- (IBAction)sendMessage:(id)sender;

@end
