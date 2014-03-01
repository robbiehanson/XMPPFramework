#import "ChatViewController.h"
#import "ServerlessDemoAppDelegate.h"
#import "Service.h"
#import "Message.h"
#import "DDXML.h"
#import "XMPPStream.h"
#import "XMPPJID.h"
#import "XMPPIQ.h"
#import "XMPPMessage.h"
#import "XMPPPresence.h"
#import "NSXMLElement+XMPP.h"
#import "NSString+DDXML.h"
#import "DDLog.h"

#import <arpa/inet.h>

// Log levels: off, error, warn, info, verbose
static const int ddLogLevel = LOG_LEVEL_VERBOSE;

// The BlueBubble and GreenBubble images are used as stretchable images.
// Stretchable images are defined using a leftCapWidth and topCapHeight.
// The rightCapWidth and bottomCapHeight are implicitly defined,
// assuming that the middle (stretchable) portion is 1 pixel.

#define kImageWidth   32
#define kImageHeight  29

#define kBlueLeftCapWidth  17
#define kBlueRightCapWidth (kImageWidth - kBlueLeftCapWidth - 1)

#define kGreenLeftCapWidth  14
#define kGreenRightCapWidth (kImageWidth - kGreenLeftCapWidth - 1)

#define kTopCapHeight    15
#define kBottomCapHeight (kImageHeight - kTopCapHeight - 1)

#define kMaxMessageContentWidth (320 - 17 - 14 - 20)

#define kTimeStampHeight 21

#define kAContentOffset 6
#define kBContentOffset kAContentOffset - 3

#define kBlueLeftContentOffset  (kBlueLeftCapWidth  - kAContentOffset)
#define kBlueRightContentOffset (kBlueRightCapWidth - kBContentOffset)

#define kGreenLeftContentOffset  (kGreenLeftCapWidth  - kBContentOffset)
#define kGreenRightContentOffset (kGreenRightCapWidth - kAContentOffset)

#define kTopContentOffset    (3)
#define kBottomContentOffset (3)

#define kNonContentWidth  (kImageWidth  - kAContentOffset - kBContentOffset)
#define kNonContentHeight (kImageHeight - kTopContentOffset - kBottomContentOffset)

#define kBubbleImageViewTag  1
#define kContentLabelTag     2
#define kTimestampLabelTag   3


@interface ChatViewController (PrivateAPI)

- (void)scrollToBottomAnimated:(BOOL)animated;

- (UITableViewCell *)newMessageBubbleCellWithIdentifier:(NSString *)cellIdentifier;
- (UIFont *)messageFont;
- (CGSize)sizeForMessageIndexPath:(NSIndexPath *)indexPath;
- (BOOL)shouldDisplayTimeStampForMessageAtIndexPath:(NSIndexPath *)indexPath;
- (void)configureCell:(UITableViewCell *)theCell atIndexPath:(NSIndexPath *)indexPath;

- (NSFetchedResultsController *)fetchedResultsController;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation ChatViewController

@synthesize service;
@synthesize managedObjectContext;

- (void)viewDidLoad
{
	textField.placeholder = @"Tap here to chat";

	[[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(keyboardWillShow:)
	                                             name:UIKeyboardWillShowNotification 
	                                           object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(keyboardWillHide:)
	                                             name:UIKeyboardWillHideNotification 
	                                           object:nil];
	
	netService = [[NSNetService alloc] initWithDomain:[service serviceDomain]
	                                             type:[service serviceType]
	                                             name:[service serviceName]];
	[netService setDelegate:self];
	[netService resolveWithTimeout:5.0];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self scrollToBottomAnimated:NO];
}

- (void)viewDidAppear:(BOOL)animated
{
    // From the documentation:
	// 
	// You can override this method to perform additional tasks associated with presenting the view.
	// If you override this method, you must call super at some point in your implementation.
    [super viewDidAppear:animated];
	
	if([[service messages] count] == 0)
    {
		[textField becomeFirstResponder];
	}
    else
    {
	//	[service markUnreadMessagesAsRead];
		
	//	// Update roster table view to eliminate the unread indicator
		// Todo...
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Notifications
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)keyboardWillShow:(NSNotification *)notification
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
	
	// Extract information about the keyboard change.
	
	float keyboardHeight;
	double animationDuration;
	
	// UIKeyboardBoundsUserInfoKey:
	// The key for an NSValue object containing a CGRect that identifies the bounds rectangle of the keyboard.
	
	CGRect beginRect = [[[notification userInfo] objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue];
	CGRect endRect   = [[[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
	
	keyboardHeight = ABS(beginRect.origin.y - endRect.origin.y);
	
	// UIKeyboardAnimationDurationUserInfoKey
	// The key for an NSValue object containing a double that identifies the duration of the animation in seconds.
	
	animationDuration = [[[notification userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
	
	// Resize the view
	
	CGRect viewFrame = [self.view frame];
	viewFrame.size.height -= keyboardHeight;
	
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:animationDuration];
	
	self.view.frame = viewFrame;
	
	[UIView commitAnimations];
	
	[self performSelector:@selector(delayedScrollToBottomAnimated:)
			   withObject:[NSNumber numberWithBool:YES]
			   afterDelay:0.3];
}

- (void)keyboardWillHide:(NSNotification *)notification
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
	
	// Extract information about the keyboard change.
	
	float keyboardHeight;
	double animationDuration;
	
	// UIKeyboardBoundsUserInfoKey:
	// The key for an NSValue object containing a CGRect that identifies the bounds rectangle of the keyboard.
	
	CGRect beginRect = [[[notification userInfo] objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue];
	CGRect endRect   = [[[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
	
	keyboardHeight = ABS(beginRect.origin.y - endRect.origin.y);
	
	// UIKeyboardAnimationDurationUserInfoKey
	// The key for an NSValue object containing a double that identifies the duration of the animation in seconds.
	
	animationDuration = [[[notification userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
	
	// Reset the height of the scroll view to its original value
	
	CGRect viewFrame = [[self view] frame];
	viewFrame.size.height += keyboardHeight;
	
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:animationDuration];
	
	self.view.frame = viewFrame;
	
	[UIView commitAnimations];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Actions
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)sendMessage:(NSString *)msgContent
{
	NSXMLElement *body = [NSXMLElement elementWithName:@"body"];
	[body setStringValue:msgContent];
	
	NSXMLElement *message = [NSXMLElement elementWithName:@"message"];
    [message addAttributeWithName:@"type" stringValue:@"chat"];
	[message addChild:body];
	
	[xmppStream sendElement:message];
	
	Message *msg = [NSEntityDescription insertNewObjectForEntityForName:@"Message"
												 inManagedObjectContext:[self managedObjectContext]];
	
	msg.content     = msgContent;
	msg.isOutbound  = YES;
	msg.hasBeenRead = YES;
	msg.timeStamp   = [NSDate date];
	
	msg.service     = service;
	
	[[self managedObjectContext] save:nil];
}

- (BOOL)textFieldShouldReturn:(UITextField *)sender
{
	NSString *msgContent = [[textField text] stringByTrimming];
	if([msgContent length] > 0)
	{
		[self sendMessage:msgContent];
	}
	
	textField.text = @"";
	return NO;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark UITableView Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)delayedScrollToBottomAnimated:(NSNumber *)animated
{
	[self scrollToBottomAnimated:[animated boolValue]];
}

- (void)scrollToBottomAnimated:(BOOL)animated
{
    NSInteger numRows = [tableView numberOfRowsInSection:0];
    if (numRows > 0)
    {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:(numRows - 1) inSection:0];
        [tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionTop animated:animated];
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)sender
{
	return [[[self fetchedResultsController] sections] count];
}

- (NSInteger)tableView:(UITableView *)sender numberOfRowsInSection:(NSInteger)sectionIndex
{
	NSArray *sections = [[self fetchedResultsController] sections];
	
	if (sectionIndex < [sections count])
	{
		id <NSFetchedResultsSectionInfo> sectionInfo = [sections objectAtIndex:sectionIndex];
		return [sectionInfo numberOfObjects];
	}
	
	return 0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	CGSize cellSize = [self sizeForMessageIndexPath:indexPath];
	
	return cellSize.height;
}

- (UITableViewCell *)tableView:(UITableView *)sender cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString *CellIdentifier = @"ChatViewController_Cell";
	
	UITableViewCell *cell = [sender dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil)
	{
		cell = [self newMessageBubbleCellWithIdentifier:CellIdentifier];
	}
	
	[self configureCell:cell atIndexPath:indexPath];
	
	return cell;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Message Cell
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (UITableViewCell *)newMessageBubbleCellWithIdentifier:(NSString *)cellIdentifier
{
	UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
	                                               reuseIdentifier:cellIdentifier];
	
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	cell.backgroundColor = [UIColor colorWithRed:(219/255.0) green:(226/255.0) blue:(237/255.0) alpha:1.0];
	
	UILabel *timestampLabel;
	UILabel *contentLabel;
	UIImageView *bubbleImageView;
	
    // Add text label for timestamp
    timestampLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, cell.frame.size.width, kTimeStampHeight)];
    timestampLabel.font = [UIFont systemFontOfSize:13];
    timestampLabel.textAlignment = NSTextAlignmentCenter;
    timestampLabel.backgroundColor = cell.backgroundColor;
    timestampLabel.opaque = YES;
    timestampLabel.tag = kTimestampLabelTag;
    timestampLabel.shadowOffset = CGSizeMake(0,1);
    timestampLabel.textColor = [UIColor colorWithRed:(33/255.0F) green:(40/255.0F) blue:(53/255.0F) alpha:1.0F];
    timestampLabel.shadowColor = [UIColor whiteColor];
	
	contentLabel = [[UILabel alloc] init];
	contentLabel.font = [self messageFont];
    contentLabel.numberOfLines = 0;
    contentLabel.backgroundColor = [UIColor clearColor];
    contentLabel.tag = kContentLabelTag;
	
    bubbleImageView = [[UIImageView alloc] initWithImage:nil];
    bubbleImageView.tag = kBubbleImageViewTag;
    
	// Note: Order matters - The contentLabel must be above the bubbleImageView
	[cell.contentView addSubview:timestampLabel];
	[cell.contentView addSubview:bubbleImageView];
	[cell.contentView addSubview:contentLabel];
    
	
    return cell;
}

- (UIFont *)messageFont
{
	return [UIFont systemFontOfSize:([UIFont systemFontSize] - 1.0F)];
}

- (CGSize)sizeForMessageIndexPath:(NSIndexPath *)indexPath
{
	Message *message = [[self fetchedResultsController] objectAtIndexPath:indexPath];
	NSString *content = message.content;
	
	UIFont *font = [self messageFont];
	
	CGSize maxContentSize = CGSizeMake(kMaxMessageContentWidth, INFINITY);
	CGSize contentSize = [content sizeWithFont:font constrainedToSize:maxContentSize];
	
	CGSize cellSize = contentSize;
	
    cellSize.width  = MAX(contentSize.width + kNonContentWidth, kImageWidth);
	cellSize.height = MAX(contentSize.height + kNonContentHeight, kImageHeight);
	
    if([self shouldDisplayTimeStampForMessageAtIndexPath:indexPath])
	{
		// Add room for timestamp
		cellSize.height += kTimeStampHeight;
	}
	
	return cellSize;
}

- (BOOL)shouldDisplayTimeStampForMessageAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.row == 0)
	{
		// Show interval for first message
		return YES;
	}
	
    // Otherwise, show stamp if messages are seperated by more than 60 seconds
	NSIndexPath *previousIndexPath = [NSIndexPath indexPathForRow:(indexPath.row - 1)
	                                                    inSection:indexPath.section];
	
	Message *currentMessage  = [[self fetchedResultsController] objectAtIndexPath:indexPath];
	Message *previousMessage = [[self fetchedResultsController] objectAtIndexPath:previousIndexPath];
	
    NSDate *currentMessageDate = currentMessage.timeStamp;
	NSDate *previousMessageDate = previousMessage.timeStamp;
	
    NSTimeInterval interval = ABS([currentMessageDate timeIntervalSinceDate:previousMessageDate]);
	
	return (interval > 60.0);
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
	// Date formatter for the time stamp
	static NSDateFormatter *dateFormatter = nil;
	if (dateFormatter == nil)
	{
		dateFormatter = [[NSDateFormatter alloc] init];
		[dateFormatter setTimeStyle:NSDateFormatterShortStyle];
		[dateFormatter setDateStyle:NSDateFormatterMediumStyle];
	}
	
	cell.userInteractionEnabled = NO;
	
	// Get message and cell views
	
	Message *message = [[self fetchedResultsController] objectAtIndexPath:indexPath];
	
	UILabel     *timeStampLabel  =     (UILabel *)[cell viewWithTag:kTimestampLabelTag];
	UILabel     *contentLabel    =     (UILabel *)[cell viewWithTag:kContentLabelTag];
	UIImageView *bubbleImageView = (UIImageView *)[cell viewWithTag:kBubbleImageViewTag];
	
	// Update message if needed
	
	if (![message hasBeenRead])
	{
		message.hasBeenRead = YES;
	}
	
	// Configure frames for everything
	
    CGSize messageSize = [self sizeForMessageIndexPath:indexPath];
	
    CGRect textFrame;
	CGRect bubbleFrame;
	
	if ([message isOutbound])
	{
		// Outgoing = GreenBubble (Right Side)
		
		bubbleFrame.origin.x = cell.frame.size.width - messageSize.width;
		bubbleFrame.origin.y = 0;
		bubbleFrame.size.width = messageSize.width;
		bubbleFrame.size.height = messageSize.height;
		
		textFrame.origin.x = bubbleFrame.origin.x + kGreenLeftContentOffset;
		textFrame.origin.y = bubbleFrame.origin.y + kTopContentOffset;
		textFrame.size.width = messageSize.width - kGreenLeftContentOffset - kGreenRightContentOffset;
		textFrame.size.height = messageSize.height - kTopContentOffset - kBottomContentOffset;
	}
	else
	{
		// Incoming = BlueBubble (Left Side)
		
		bubbleFrame.origin.x = 0;
		bubbleFrame.origin.y = 0;
		bubbleFrame.size.width = messageSize.width;
		bubbleFrame.size.height = messageSize.height;
		
		textFrame.origin.x = bubbleFrame.origin.x + kBlueLeftContentOffset;
		textFrame.origin.y = bubbleFrame.origin.y + kTopContentOffset;
		textFrame.size.width = messageSize.width - kBlueLeftContentOffset - kBlueRightContentOffset;
		textFrame.size.height = messageSize.height - kTopContentOffset - kBottomContentOffset;
	}
	
    // Timestamp
	
    if ([self shouldDisplayTimeStampForMessageAtIndexPath:indexPath])
    {
		textFrame.size.height -= kTimeStampHeight;
		textFrame.origin.y += kTimeStampHeight;
		
		bubbleFrame.origin.y += kTimeStampHeight;
		bubbleFrame.size.height -= kTimeStampHeight;
		
        timeStampLabel.hidden = NO;
        timeStampLabel.text = [dateFormatter stringFromDate:[message timeStamp]];
	}
	else
	{
		timeStampLabel.hidden = YES;
    }
	
    // Content
	
    contentLabel.text = message.content;
    contentLabel.font = [self messageFont];
	
    // Bubble Image
	
	if ([message isOutbound])
	{
		UIImage *img = [[UIImage imageNamed:@"GreenBubble.png"] stretchableImageWithLeftCapWidth:kGreenLeftCapWidth
		                                                                            topCapHeight:kTopCapHeight];
		bubbleImageView.image = img;
        contentLabel.textAlignment = NSTextAlignmentLeft;
    }
    else
    {
		UIImage *img = [[UIImage imageNamed:@"BlueBubble.png"] stretchableImageWithLeftCapWidth:kBlueLeftCapWidth
		                                                                           topCapHeight:kTopCapHeight];
        bubbleImageView.image = img;
        contentLabel.textAlignment = NSTextAlignmentLeft;
    }
	
	contentLabel.frame = textFrame;
    bubbleImageView.frame = bubbleFrame;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark FetchedResultsController
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSFetchedResultsController *)fetchedResultsController
{
    if (fetchedResultsController == nil)
    {
		NSSortDescriptor *dateSD;
		NSArray *sortDescriptors;
		NSFetchRequest *fetchRequest;
		
		NSEntityDescription *entity = [NSEntityDescription entityForName:@"Message"
		                                          inManagedObjectContext:managedObjectContext];
		
		dateSD = [[NSSortDescriptor alloc] initWithKey:@"timeStamp" ascending:YES];
		sortDescriptors = [[NSArray alloc] initWithObjects:dateSD, nil];
		
		NSPredicate * predicate = [NSPredicate predicateWithFormat:@"service = %@", service];
		
		fetchRequest = [[NSFetchRequest alloc] init];
		[fetchRequest setEntity:entity];
		[fetchRequest setFetchBatchSize:10];
		[fetchRequest setPredicate:predicate];
		[fetchRequest setSortDescriptors:sortDescriptors];
		
		// Edit the section name key path and cache name if appropriate.
		// nil for section name key path means "no sections".
		fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
		                                                               managedObjectContext:managedObjectContext
		                                                                 sectionNameKeyPath:nil
		                                                                          cacheName:nil];
		fetchedResultsController.delegate = self;
		
		NSError *error = nil;
        if (![fetchedResultsController performFetch:&error])
        {
			DDLogError(@"Error fetching messages: %@ %@", error, [error userInfo]);
        }
		
    }
	
    return fetchedResultsController;
}

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    if (![self isViewLoaded]) return;
	
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
	
    [tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller
   didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath
     forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
	if (![self isViewLoaded]) return;
	
    switch(type)
    {
        case NSFetchedResultsChangeInsert:
			DDLogVerbose(@"%@: NSFetchedResultsChangeInsert: %@", THIS_FILE, newIndexPath);
			
            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath]
			                 withRowAnimation:UITableViewRowAnimationFade];
			break;
			
        case NSFetchedResultsChangeDelete:
            DDLogVerbose(@"%@: NSFetchedResultsChangeDelete: %@", THIS_FILE, indexPath);
			
			[tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
			                 withRowAnimation:UITableViewRowAnimationFade];
            break;
			
        case NSFetchedResultsChangeUpdate:
			DDLogVerbose(@"%@: NSFetchedResultsChangeUpdate: %@", THIS_FILE, indexPath);
			
			[tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
			                 withRowAnimation:UITableViewRowAnimationNone];
			break;
			
        case NSFetchedResultsChangeMove:
            DDLogVerbose(@"%@: NSFetchedResultsChangeMove: %@ -> %@", THIS_FILE, indexPath, newIndexPath);
			
			[tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
			                 withRowAnimation:UITableViewRowAnimationFade];
			
			[tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath]
			                 withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    if (![self isViewLoaded]) return;
	
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
	
    [tableView endUpdates];
	
	[self scrollToBottomAnimated:YES];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark NSNetService Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)netServiceDidResolveAddress:(NSNetService *)ns
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
	
	// The iPhone only supports IPv4, so we need to get the IPv4 address from the resolve operation.
	
	ServerlessDemoAppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
	NSData *address = [appDelegate IPv4AddressFromAddresses:[ns addresses]];
	NSString *addrStr = [appDelegate stringFromAddress:address];
	
	if (address)
	{
		// Update the lastResolvedAddress for the service
		
		service.lastResolvedAddress = addrStr;
		
		// Create an xmpp stream to the service with the resolved address
		
		XMPPJID *myJID      = [appDelegate myJID];
		XMPPJID *serviceJID = [XMPPJID jidWithString:[service serviceName]];
		
		DDLogVerbose(@"%@: myJID(%@) serviceJID(%@)", THIS_FILE, myJID, serviceJID);
		
		xmppStream = [[XMPPStream alloc] initP2PFrom:myJID];
		
		[xmppStream addDelegate:self delegateQueue:dispatch_get_main_queue()];
		[xmppStream connectTo:serviceJID withAddress:address withTimeout:XMPPStreamTimeoutNone error:nil];
	}
	
	[ns stop];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStream Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppStreamDidConnect:(XMPPStream *)sender
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
}

- (void)xmppStream:(XMPPStream *)sender willSendP2PFeatures:(NSXMLElement *)streamFeatures
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
}

- (void)xmppStream:(XMPPStream *)sender didReceiveP2PFeatures:(NSXMLElement *)streamFeatures
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
	
	return NO;
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
	
	NSString *msgBody = [[[message elementForName:@"body"] stringValue] stringByTrimming];
	if ([msgBody length] > 0)
	{
		Message *msg = [NSEntityDescription insertNewObjectForEntityForName:@"Message"
													 inManagedObjectContext:[self managedObjectContext]];
		
		msg.content     = msgBody;
		msg.isOutbound  = NO;
		msg.hasBeenRead = NO;
		msg.timeStamp   = [NSDate date];
		
		msg.service     = service;
		
		[[self managedObjectContext] save:nil];
	}
}

- (void)xmppStream:(XMPPStream *)sender didReceivePresence:(XMPPPresence *)presence
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
}

- (void)xmppStream:(XMPPStream *)sender didReceiveError:(id)error
{
	DDLogVerbose(@"%@: %@ %@", THIS_FILE, THIS_METHOD, error);
}

- (void)xmppStreamDidDisconnect:(XMPPStream *)sender withError:(NSError *)error
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Memory Management
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)didReceiveMemoryWarning
{
	// Releases the view if it doesn't have a superview.
	[super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)dealloc
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
	
	
	[netService setDelegate:nil];
	[netService stop];
	
	[xmppStream removeDelegate:self];
	[xmppStream disconnect];
	
	
}


@end
