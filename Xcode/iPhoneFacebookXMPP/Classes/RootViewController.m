#import "RootViewController.h"
#import "iPhoneFacebookXMPPAppDelegate.h"
#import "SettingsViewController.h"

#import "XMPPFramework.h"
#import "DDLog.h"

// Log levels: off, error, warn, info, verbose
#if DEBUG
  static const int ddLogLevel = LOG_LEVEL_VERBOSE;
#else
  static const int ddLogLevel = LOG_LEVEL_INFO;
#endif

@implementation RootViewController

- (iPhoneFacebookXMPPAppDelegate*)appDelegate
{
    return [iPhoneFacebookXMPPAppDelegate sharedAppDelegate];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark View lifecycle
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
  
	UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 400, 44)];
	titleLabel.backgroundColor = [UIColor clearColor];
	titleLabel.textColor = [UIColor whiteColor];
	titleLabel.font = [UIFont boldSystemFontOfSize:20.0];
	titleLabel.numberOfLines = 1;
	titleLabel.adjustsFontSizeToFitWidth = YES;
	titleLabel.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.5];
	titleLabel.textAlignment = UITextAlignmentCenter;

    titleLabel.text = [self appDelegate].settingsViewController.statusLabel.text;	
	[titleLabel sizeToFit];

	self.navigationItem.titleView = titleLabel;
}

- (void)viewWillDisappear:(BOOL)animated {  
  [[[self appDelegate] xmppvCardTempModule] removeDelegate:self];
  
  [super viewWillDisappear:animated];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark NSFetchedResultsController
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSFetchedResultsController *)fetchedResultsController
{
	if (fetchedResultsController == nil)
	{
		NSManagedObjectContext *moc = [[self appDelegate] managedObjectContext_roster];
		
		NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPUserCoreDataStorageObject"
		                                          inManagedObjectContext:moc];
		
		NSSortDescriptor *sd1 = [[NSSortDescriptor alloc] initWithKey:@"sectionNum" ascending:YES];
		NSSortDescriptor *sd2 = [[NSSortDescriptor alloc] initWithKey:@"displayName" ascending:YES];
		
		NSArray *sortDescriptors = [NSArray arrayWithObjects:sd1, sd2, nil];
		
		NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
		[fetchRequest setEntity:entity];
		[fetchRequest setSortDescriptors:sortDescriptors];
		[fetchRequest setFetchBatchSize:10];
		
		fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
		                                                               managedObjectContext:moc
		                                                                 sectionNameKeyPath:@"sectionNum"
		                                                                          cacheName:nil];
		[fetchedResultsController setDelegate:self];
		
		
		NSError *error = nil;
		if (![fetchedResultsController performFetch:&error])
		{
			DDLogError(@"Error performing fetch: %@", error);
		}
	
	}
	
	return fetchedResultsController;
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
	[[self tableView] reloadData];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark UITableViewCell helpers
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)configurePhotoForCell:(UITableViewCell *)cell user:(XMPPUserCoreDataStorageObject *)user
{
	// Our xmppRosterStorage will cache photos as they arrive from the xmppvCardAvatarModule.
	// We only need to ask the avatar module for a photo, if the roster doesn't have it.
	
	if (user.photo != nil)
	{
		cell.imageView.image = user.photo;
	} 
	else
	{
		NSData *photoData = [[[self appDelegate] xmppvCardAvatarModule] photoDataForJID:user.jid];

		if (photoData != nil)
			cell.imageView.image = [UIImage imageWithData:photoData];
		else
			cell.imageView.image = [UIImage imageNamed:@"defaultPerson"];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark UITableView
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return [[[self fetchedResultsController] sections] count];
}

- (NSString *)tableView:(UITableView *)sender titleForHeaderInSection:(NSInteger)sectionIndex
{
	NSArray *sections = [[self fetchedResultsController] sections];
	
	if (sectionIndex < [sections count])
	{
		id <NSFetchedResultsSectionInfo> sectionInfo = [sections objectAtIndex:sectionIndex];
        
		int section = [sectionInfo.name intValue];
		switch (section)
		{
			case 0  : return @"Available";
			case 1  : return @"Away";
			default : return @"Offline";
		}
	}
	
	return @"";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)sectionIndex
{
	NSArray *sections = [[self fetchedResultsController] sections];
	
	if (sectionIndex < [sections count])
	{
		id <NSFetchedResultsSectionInfo> sectionInfo = [sections objectAtIndex:sectionIndex];
		return sectionInfo.numberOfObjects;
	}
	
	return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString *CellIdentifier = @"Cell";
	
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
	if (cell == nil)
	{
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
		                               reuseIdentifier:CellIdentifier];
	}
	
	XMPPUserCoreDataStorageObject *user = [[self fetchedResultsController] objectAtIndexPath:indexPath];
	
	cell.textLabel.text = user.displayName;
	[self configurePhotoForCell:cell user:user];
	
	return cell;
}

#pragma mark -
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    XMPPUserCoreDataStorageObject *user = [self.fetchedResultsController objectAtIndexPath:indexPath];

    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Enter a message" message:[user jidStr] delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    [alert show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    NSString *recipientJid = alertView.message;
    NSString *msgContent = [alertView textFieldAtIndex:0].text;
    if([msgContent length] > 0)
    {
        NSXMLElement *body = [NSXMLElement elementWithName:@"body"];
        [body setStringValue:msgContent];
        
        NSXMLElement *message = [NSXMLElement elementWithName:@"message"];
        [message addAttributeWithName:@"type" stringValue:@"chat"];
        [message addAttributeWithName:@"to" stringValue:recipientJid];
        [message addChild:body];
        
        [[[self appDelegate] xmppStream] sendElement:message];
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Actions
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (IBAction)settings:(id)sender
{
	[self.navigationController presentModalViewController:[[self appDelegate] settingsViewController] animated:YES];
}

@end
