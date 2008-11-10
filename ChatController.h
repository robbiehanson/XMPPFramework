#import <Cocoa/Cocoa.h>
@class   XMPPClient;
@class   XMPPMessage;
@class   XMPPJID;


@interface ChatController : NSWindowController
{
	XMPPClient *xmppClient;
	XMPPJID *jid;
	
	XMPPMessage *firstMessage;
	
    IBOutlet id messageField;
    IBOutlet id messageView;
}

- (id)initWithXMPPClient:(XMPPClient *)client jid:(XMPPJID *)fullJID;
- (id)initWithXMPPClient:(XMPPClient *)client jid:(XMPPJID *)fullJID message:(XMPPMessage *)message;

- (XMPPJID *)jid;

- (IBAction)sendMessage:(id)sender;

@end
