#import <Cocoa/Cocoa.h>
@class   XMPPClient;
@class   XMPPJID;


@interface ChatController : NSWindowController
{
	XMPPClient *xmppClient;
	XMPPJID *jid;
	
    IBOutlet id messageField;
    IBOutlet id messageView;
}

- (id)initWithXMPPClient:(XMPPClient *)client jid:(XMPPJID *)fullJID;

- (XMPPJID *)jid;

- (IBAction)sendMessage:(id)sender;

@end
