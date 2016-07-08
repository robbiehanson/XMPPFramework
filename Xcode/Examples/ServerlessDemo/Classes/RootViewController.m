#import "RootViewController.h"
#import "ChatViewController.h"
#import "Service.h"
#import "DDLog.h"

// Log levels: off, error, warn, info, verbose
static const int ddLogLevel = LOG_LEVEL_VERBOSE;


@interface RootViewController (PrivateAPI)

- (NSFetchedResultsController *)fetchedResultsController;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation RootViewController

@synthesize managedObjectContext;

- (void)viewDidLoad
{
	// Configure UI
	
	self.title = @"Roster";
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Table view methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSInteger)numberOfSectionsInTableView:(UITableView *)sender
{
	return [[[self fetchedResultsController] sections] count];
}

- (NSString *)tableView:(UITableView *)sender titleForHeaderInSection:(NSInteger)sectionIndex
{
	NSArray *sections = [[self fetchedResultsController] sections];
	
	if ([sections count] > sectionIndex)
	{
		id <NSFetchedResultsSectionInfo> sectionInfo = [sections objectAtIndex:sectionIndex];
		
		StatusType statusType = [sectionInfo.name intValue];
		
		return [Service statusDisplayTitleForStatusType:statusType];
	}
	
	return @"";
}

- (NSInteger)tableView:(UITableView *)sender numberOfRowsInSection:(NSInteger)sectionIndex
{
	NSArray *sections = [[self fetchedResultsController] sections];
	
	if ([sections count] > sectionIndex)
	{
		id <NSFetchedResultsSectionInfo> sectionInfo = [sections objectAtIndex:sectionIndex];
		return [sectionInfo numberOfObjects];
	}
	
	return 0;
}

- (UITableViewCell *)tableView:(UITableView *)sender cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString *CellIdentifier = @"RootViewController_Cell";
	
    UITableViewCell *cell = [sender dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil)
	{
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
		                               reuseIdentifier:CellIdentifier];
		
	//	UIButton *unreadIndicator = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 33, 22)];
		UIButton *unreadIndicator = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 30, 20)];
        
        [unreadIndicator setEnabled:NO];
        
        [unreadIndicator setTitleColor:[UIColor whiteColor]
                              forState:UIControlStateDisabled];
        
        [unreadIndicator setBackgroundImage:[UIImage imageNamed:@"UnreadIndicator.png"]
                                   forState:UIControlStateDisabled];
        
        cell.accessoryView = unreadIndicator;
    }
    
	Service *service = [fetchedResultsController objectAtIndexPath:indexPath];
	
	cell.textLabel.text = [service displayName];
	cell.detailTextLabel.text = [service statusMessage];
	
	NSUInteger numberOfUnreadMessages = [service numberOfUnreadMessages];
	if (numberOfUnreadMessages > 0)
	{
		UIButton *unreadIndicator = (UIButton *)cell.accessoryView;
		NSString *unreadTitle = [NSString stringWithFormat:@"%lu", (unsigned long)numberOfUnreadMessages];
		
		[unreadIndicator setTitle:unreadTitle forState:UIControlStateDisabled];
		
		cell.accessoryView.hidden = NO;
	}
	else
	{
		cell.accessoryView.hidden = YES;
	}
	
    return cell;
}

- (void)tableView:(UITableView *)sender didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	Service *service = (Service *)[[self fetchedResultsController] objectAtIndexPath:indexPath];
	
	ChatViewController *chatVC = [[ChatViewController alloc] initWithNibName:@"ChatViewController" bundle:nil];
	chatVC.managedObjectContext = self.managedObjectContext;
	chatVC.service = service;
	
	[self.navigationController pushViewController:chatVC animated:YES];
	
	
	[sender deselectRowAtIndexPath:indexPath animated:YES];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Fetched results controller
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSFetchedResultsController *)fetchedResultsController
{
	if (fetchedResultsController == nil)
	{
		NSSortDescriptor *statusSD;
		NSSortDescriptor *nameSD;
		NSArray *sortDescriptors;
		NSFetchRequest *fetchRequest;
		
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Service"
		                                          inManagedObjectContext:managedObjectContext];
		
        statusSD = [[NSSortDescriptor alloc] initWithKey:@"status" ascending:NO];
		nameSD = [[NSSortDescriptor alloc] initWithKey:@"displayName" ascending:NO];
		
		sortDescriptors = [[NSArray alloc] initWithObjects:statusSD, nameSD, nil];
		
		fetchRequest = [[NSFetchRequest alloc] init];
		[fetchRequest setFetchBatchSize:10];
		[fetchRequest setEntity:entity];
		[fetchRequest setSortDescriptors:sortDescriptors];
		
		fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest 
		                                                  managedObjectContext:managedObjectContext 
		                                                    sectionNameKeyPath:@"status"
		                                                             cacheName:nil];
        fetchedResultsController.delegate = self;
        
        NSError *error = nil;
        if (![fetchedResultsController performFetch:&error])
        {
			DDLogError(@"%@: Error fetching messages: %@ %@", THIS_FILE, error, [error userInfo]);
        }
        
    }
    
	return fetchedResultsController;
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
	if(![self isViewLoaded]) return;
	
	DDLogVerbose(@"%@: controllerDidChangeContent", THIS_FILE);
	
	[self.tableView reloadData];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Memory management
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
}


@end
