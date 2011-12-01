#import <Cocoa/Cocoa.h>
#import "XMPPFramework.h"


@interface MucController : NSWindowController <NSWindowDelegate>
{
	__strong XMPPStream * xmppStream;
	__strong XMPPRoom   * xmppRoom;
	__strong XMPPRoomMemoryStorage *xmppRoomStorage;
	
	NSArray *messages;
	NSArray *occupants;
	
	BOOL started;
	
	IBOutlet NSTableView * messagesTableView;
	IBOutlet NSTextField * sendMessageField;
	IBOutlet NSTextField * logField;
	IBOutlet NSTableView * occupantsTableView;
}

- (id)initWithStream:(XMPPStream *)stream roomJID:(XMPPJID *)roomJID;

@property (nonatomic, readonly) XMPPStream *xmppStream;
@property (nonatomic, readonly) XMPPJID *jid;


- (IBAction)sendMessage:(id)sender;

@end
