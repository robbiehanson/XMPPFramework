#import <Cocoa/Cocoa.h>
#import "XMPPFramework.h"


@interface MucController : NSWindowController <NSWindowDelegate>
{
	__strong XMPPStream * xmppStream;
	__strong XMPPRoom   * xmppRoom;
	__strong id <XMPPRoomStorage> xmppRoomStorage;
	
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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface MessageCellView : NSTableCellView

@property (nonatomic, strong) IBOutlet NSTextField *nicknameField;
@property (nonatomic, strong) IBOutlet NSTextField *messageField;

- (CGFloat)fittingHeight;

@end
