#import "MucController.h"
#import "WindowManager.h"
#import "XMPPFramework.h"
#import "DDLog.h"

// Log levels: off, error, warn, info, verbose
static const int ddLogLevel = LOG_LEVEL_VERBOSE;


@implementation MucController

- (id)initWithStream:(XMPPStream *)stream roomJID:(XMPPJID *)roomJID
{
	if ((self = [super initWithWindowNibName:@"MucWindow"]))
	{
		xmppStream = stream;
		
		xmppRoomStorage = [[XMPPRoomMemoryStorage alloc] init];
		xmppRoom = [[XMPPRoom alloc] initWithRoomStorage:xmppRoomStorage jid:roomJID];
		
		[xmppRoom addDelegate:self delegateQueue:dispatch_get_main_queue()];
		[xmppRoom activate:xmppStream];
	}
	return self;
}

- (void)awakeFromNib
{
	[xmppRoom createOrJoinRoomUsingNickname:@"xmppFrameworkMucTest"];
}

- (void)windowWillClose:(NSNotification *)notification
{
	[xmppRoom leaveRoom];
	[xmppRoom deactivate];
	[xmppRoom removeDelegate:self];
	
	[WindowManager closeMucWindow:self];
}

- (void)dealloc
{
	DDLogVerbose(@"Deallocating self: %@", self);
	
	[xmppRoom deactivate];
	[xmppRoom removeDelegate:self];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Properties
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@synthesize xmppStream;

- (XMPPJID *)jid
{
	return xmppRoom.roomJID;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark IBActions
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (IBAction)sendMessage:(id)sender
{
	
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark NSTableView Datasource
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	if (tableView == messagesTableView)
		return [messages count];
	else
		return [occupants count];
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
	if (tableView == messagesTableView)
	{
		id <XMPPRoomMessage> message = [messages objectAtIndex:row];
		NSString *str = [NSString stringWithFormat:@"%@:\n%@", message.nickname, message.body];
		
		NSTableColumn *col = [[messagesTableView tableColumns] objectAtIndex:0];
		NSCell *colDataCell = [col dataCell];
		
		float width = [col width];
		NSFont *font = [colDataCell font];
		
		NSTextStorage *textStorage = [[NSTextStorage alloc] initWithString:str];
		NSTextContainer *textContainer = [[NSTextContainer alloc] initWithContainerSize:NSMakeSize(width, FLT_MAX)];
		NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
		
		[layoutManager addTextContainer:textContainer];
		[textStorage addLayoutManager:layoutManager];
		
		[textStorage addAttribute:NSFontAttributeName value:font range:NSMakeRange(0, [textStorage length])];
		[textContainer setLineFragmentPadding:0.0];
		
		(void) [layoutManager glyphRangeForTextContainer:textContainer];
		NSRect rct = [layoutManager usedRectForTextContainer:textContainer];
		
		float height = rct.size.height;
		return height;
	}
	else
	{
		return occupantsTableView.rowHeight;
	}
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	if (tableView == messagesTableView)
	{
		id <XMPPRoomMessage> message = [messages objectAtIndex:rowIndex];
		return [NSString stringWithFormat:@"%@:\n%@", message.nickname, message.body];
	}
	else
	{
		id <XMPPRoomOccupant> occupant = [occupants objectAtIndex:rowIndex];
		return occupant.nickname;
	}
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPRoom Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppRoomDidCreate:(XMPPRoom *)sender
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
	[logField setStringValue:@"did create room"];
}

- (void)xmppRoomDidJoin:(XMPPRoom *)sender
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
	[logField setStringValue:@"did join room"];
}

- (void)xmppRoomDidLeave:(XMPPRoom *)sender
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
	[logField setStringValue:@"did leave room"];
}

- (void)xmppRoom:(XMPPRoom *)sender occupantDidJoin:(XMPPJID *)occupantJID
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
	[logField setStringValue:[NSString stringWithFormat:@"occupant did join: %@", [occupantJID resource]]];
}

- (void)xmppRoom:(XMPPRoom *)sender occupantDidLeave:(XMPPJID *)occupantJID
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
	[logField setStringValue:[NSString stringWithFormat:@"occupant did join: %@", [occupantJID resource]]];
}

- (void)xmppRoom:(XMPPRoom *)sender didReceiveMessage:(XMPPMessage *)message fromOccupant:(XMPPJID *)occupantJID
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
	[logField setStringValue:[NSString stringWithFormat:@"did receive msg from: %@", [occupantJID resource]]];
}

- (void)xmppRoomMemoryStorage:(XMPPRoomMemoryStorage *)sender
              occupantDidJoin:(XMPPRoomOccupantMemoryStorage *)occupant
                      atIndex:(NSUInteger)index
                      inArray:(NSArray *)allOccupants {
	
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
	
	occupants = allOccupants;
	
	NSIndexSet *indexes = [NSIndexSet indexSetWithIndex:index];
	
	[occupantsTableView beginUpdates];
	[occupantsTableView insertRowsAtIndexes:indexes withAnimation:NSTableViewAnimationEffectGap];
	[occupantsTableView endUpdates];
}


- (void)xmppRoomMemoryStorage:(XMPPRoomMemoryStorage *)sender
             occupantDidLeave:(XMPPRoomOccupantMemoryStorage *)occupant
                      atIndex:(NSUInteger)index
                    fromArray:(NSArray *)allOccupants {
	
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
	
	occupants = allOccupants;
	
	NSIndexSet *indexes = [NSIndexSet indexSetWithIndex:index];
	
	[occupantsTableView beginUpdates];
	[occupantsTableView removeRowsAtIndexes:indexes withAnimation:NSTableViewAnimationEffectGap];
	[occupantsTableView endUpdates];
}


- (void)xmppRoomMemoryStorage:(XMPPRoomMemoryStorage *)sender
            occupantDidUpdate:(XMPPRoomOccupantMemoryStorage *)occupant
                    fromIndex:(NSUInteger)oldIndex
                      toIndex:(NSUInteger)newIndex
                      inArray:(NSArray *)allOccupants {
	
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
	
	occupants = allOccupants;
	
	if (oldIndex == newIndex)
	{
		NSIndexSet *rowIndexes = [NSIndexSet indexSetWithIndex:oldIndex];
		NSIndexSet *colIndexes = [NSIndexSet indexSetWithIndex:0];
		
		[occupantsTableView beginUpdates];
		[occupantsTableView reloadDataForRowIndexes:rowIndexes columnIndexes:colIndexes];
		[occupantsTableView endUpdates];
	}
	else
	{
		[occupantsTableView beginUpdates];
		[occupantsTableView moveRowAtIndex:oldIndex toIndex:newIndex];
		[occupantsTableView endUpdates];
	}
}


- (void)xmppRoomMemoryStorage:(XMPPRoomMemoryStorage *)sender
			didReceiveMessage:(XMPPRoomMessageMemoryStorage *)message
                 fromOccupant:(XMPPRoomOccupantMemoryStorage *)occupantJID
                      atIndex:(NSUInteger)index
                      inArray:(NSArray *)allMessages {
	
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
	
	messages = allMessages;
	
	NSIndexSet *indexes = [NSIndexSet indexSetWithIndex:index];
	
	[messagesTableView beginUpdates];
	[messagesTableView insertRowsAtIndexes:indexes withAnimation:NSTableViewAnimationSlideUp];
	[messagesTableView endUpdates];
}

@end
