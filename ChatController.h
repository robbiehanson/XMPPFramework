#import <Cocoa/Cocoa.h>

@class XMPPStream;
@class XMPPMessage;
@class XMPPJID;


@interface ChatController : NSWindowController
{
	XMPPStream *xmppStream;
	XMPPJID *jid;
	XMPPMessage *firstMessage;
	
    IBOutlet id messageField;
    IBOutlet id messageView;
}

- (id)initWithStream:(XMPPStream *)xmppStream jid:(XMPPJID *)fullJID;
- (id)initWithStream:(XMPPStream *)xmppStream jid:(XMPPJID *)fullJID message:(XMPPMessage *)message;

@property (nonatomic, readonly) XMPPStream *xmppStream;
@property (nonatomic, readonly) XMPPJID *jid;

- (IBAction)sendMessage:(id)sender;

@end
