#import <Cocoa/Cocoa.h>

@class XMPPStream;
@class XMPPMessage;
@class XMPPJID;


@interface ChatController : NSWindowController
{
	__strong XMPPStream *xmppStream;
	__strong XMPPJID *jid;
	__strong XMPPMessage *firstMessage;
	
    IBOutlet id messageField;
    IBOutlet id messageView;
}

- (id)initWithStream:(XMPPStream *)xmppStream jid:(XMPPJID *)jid;
- (id)initWithStream:(XMPPStream *)xmppStream jid:(XMPPJID *)jid message:(XMPPMessage *)message;

@property (nonatomic, readonly) XMPPStream *xmppStream;
@property (nonatomic, readonly) XMPPJID *jid;

- (IBAction)sendMessage:(id)sender;

@end
