#import "RootViewController.h"
#import "SettingsViewController.h"
#import "iPhoneXMPPAppDelegate.h"

#import "XMPP.h"
#import "XMPPRosterCoreDataStorage.h"
#import "XMPPUserCoreDataStorage.h"
#import "XMPPResourceCoreDataStorage.h"
#import "XMPPvCardAvatarModule.h"

#import "DDLog.h"

// Log levels: off, error, warn, info, verbose
static const int ddLogLevel = LOG_LEVEL_VERBOSE;


@implementation RootViewController

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Accessors
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (iPhoneXMPPAppDelegate *)appDelegate
{
	return (iPhoneXMPPAppDelegate *)[[UIApplication sharedApplication] delegate];
}

- (XMPPStream *)xmppStream
{
	return [[self appDelegate] xmppStream];
}

- (XMPPRoster *)xmppRoster
{
	return [[self appDelegate] xmppRoster];
}

- (XMPPRosterCoreDataStorage *)xmppRosterStorage
{
	return [[self appDelegate] xmppRosterStorage];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark View lifecycle
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  
  UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 400, 44)];
  titleLabel.backgroundColor = [UIColor clearColor];
  titleLabel.textColor = [UIColor whiteColor];
  titleLabel.font = [UIFont boldSystemFontOfSize:20.0];
  titleLabel.numberOfLines = 1;
  titleLabel.adjustsFontSizeToFitWidth = YES;
  titleLabel.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.5];
  titleLabel.textAlignment = UITextAlignmentCenter;
  
  /*
   * monitor for vCard changes, so we can reload the tableView
   */
  [[[self appDelegate] xmppvCardTempModule] addDelegate:self delegateQueue:dispatch_get_main_queue()];

  
  if ([[self appDelegate] connect]) 
  {
    titleLabel.text = [[[[self appDelegate] xmppStream] myJID] bare];
  } else
  {
    titleLabel.text = @"No JID";
  }
  
  self.navigationItem.titleView = titleLabel;
  
  [titleLabel release];
}

- (void)viewWillDisappear:(BOOL)animated {
  [[self appDelegate] disconnect];
  
  [[[self appDelegate] xmppvCardTempModule] removeDelegate:self];
  
  [super viewWillDisappear:animated];
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Core Data
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSManagedObjectContext *)managedObjectContext
{
	if (managedObjectContext == nil)
	{
		managedObjectContext = [[NSManagedObjectContext alloc] init];
		
		NSPersistentStoreCoordinator *psc = [[self xmppRosterStorage] persistentStoreCoordinator];
		[managedObjectContext setPersistentStoreCoordinator:psc];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
		                                         selector:@selector(contextDidSave:)
		                                             name:NSManagedObjectContextDidSaveNotification
		                                           object:nil];
	}
	
	return managedObjectContext;
}

- (void)contextDidSave:(NSNotification *)notification
{
	NSManagedObjectContext *sender = (NSManagedObjectContext *)[notification object];
	
	if (sender != managedObjectContext &&
      [sender persistentStoreCoordinator] == [managedObjectContext persistentStoreCoordinator])
	{
		DDLogError(@"%@: %@", THIS_FILE, THIS_METHOD);
		
		[managedObjectContext performSelectorOnMainThread:@selector(mergeChangesFromContextDidSaveNotification:)
		                                       withObject:notification
		                                    waitUntilDone:NO];
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark NSFetchedResultsController
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSFetchedResultsController *)fetchedResultsController
{
	if (fetchedResultsController == nil)
	{
		NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPUserCoreDataStorage"
		                                          inManagedObjectContext:[self managedObjectContext]];
		
		NSSortDescriptor *sd1 = [[NSSortDescriptor alloc] initWithKey:@"sectionNum" ascending:YES];
		NSSortDescriptor *sd2 = [[NSSortDescriptor alloc] initWithKey:@"displayName" ascending:YES];
		
		NSArray *sortDescriptors = [NSArray arrayWithObjects:sd1, sd2, nil];
		
		NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
		[fetchRequest setEntity:entity];
		[fetchRequest setSortDescriptors:sortDescriptors];
		[fetchRequest setFetchBatchSize:10];
		
		fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
		                                                               managedObjectContext:[self managedObjectContext]
		                                                                 sectionNameKeyPath:@"sectionNum"
		                                                                          cacheName:nil];
		[fetchedResultsController setDelegate:self];
		
		[sd1 release];
		[sd2 release];
		[fetchRequest release];
		
		NSError *error = nil;
		if (![fetchedResultsController performFetch:&error])
		{
			NSLog(@"Error performing fetch: %@", error);
		}
	
	}
	
	return fetchedResultsController;
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
	[[self tableView] reloadData];
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
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
		                               reuseIdentifier:CellIdentifier] autorelease];
	}
	
	XMPPUserCoreDataStorage *user = [[self fetchedResultsController] objectAtIndexPath:indexPath];
	
	cell.textLabel.text = user.displayName;
	
  NSData *photoData = [[[self appDelegate] xmppvCardAvatarModule] photoDataForJID:user.jid];
  
  if (photoData != nil) {
    cell.imageView.image = [UIImage imageWithData:photoData];
  } else {
    cell.imageView.image = [UIImage imageNamed:@"defaultPerson"];
  }

	return cell;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Actions
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (IBAction)settings:(id)sender {
  [self.navigationController presentModalViewController:[[self appDelegate] settingsViewController] animated:YES];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Init/dealloc
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)dealloc
{
	[super dealloc];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPvCardTempModuleDelegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppvCardTempModule:(XMPPvCardTempModule *)vCardTempModule 
        didReceivevCardTemp:(XMPPvCardTemp *)vCardTemp 
                     forJID:(XMPPJID *)jid {
  DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
  
  /*
   *  Reloading just the changed row, if it is visible would be a better solution.
   */
  [self.tableView reloadData];
}

@end
