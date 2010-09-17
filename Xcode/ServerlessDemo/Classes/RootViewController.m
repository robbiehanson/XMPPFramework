#import "RootViewController.h"
#import "ChatViewController.h"
#import "Service.h"

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
	// Initialize variables
	
	deletedSections  = [[NSMutableIndexSet alloc] init];
	insertedSections = [[NSMutableIndexSet alloc] init];
	
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
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
		                               reuseIdentifier:CellIdentifier] autorelease];
		
	//	UIButton *unreadIndicator = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 33, 22)];
		UIButton *unreadIndicator = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 30, 20)];
        
        [unreadIndicator setEnabled:NO];
        
        [unreadIndicator setTitleColor:[UIColor whiteColor]
                              forState:UIControlStateDisabled];
        
        [unreadIndicator setBackgroundImage:[UIImage imageNamed:@"UnreadIndicator.png"]
                                   forState:UIControlStateDisabled];
        
        cell.accessoryView = unreadIndicator;
        [unreadIndicator release];
    }
    
	Service *service = [fetchedResultsController objectAtIndexPath:indexPath];
	
	cell.textLabel.text = [service displayName];
	cell.detailTextLabel.text = [service statusMessage];
	
	NSUInteger numberOfUnreadMessages = [service numberOfUnreadMessages];
	if (numberOfUnreadMessages > 0)
	{
		UIButton *unreadIndicator = (UIButton *)cell.accessoryView;
		NSString *unreadTitle = [NSString stringWithFormat:@"%lu", numberOfUnreadMessages];
		
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
	
	[chatVC release];
	
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
			NSLog(@"Error fetching messages: %@ %@", error, [error userInfo]);
        }
        
        [statusSD release];
		[nameSD release];
		[sortDescriptors release];
        [fetchRequest release];
    }
    
	return fetchedResultsController;
}    

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
	if(![self isViewLoaded]) return;
	
	NSLog(@"controllerWillChangeContent");
	
	[self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller
   didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath
     forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
	if(![self isViewLoaded]) return;
	
	switch(type) 
	{
		case NSFetchedResultsChangeInsert:
			NSLog(@"NSFetchedResultsChangeInsert[Object]");
			
			[self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath]
								  withRowAnimation:UITableViewRowAnimationFade];
			break;
			
		case NSFetchedResultsChangeDelete:
			NSLog(@"NSFetchedResultsChangeDelete[Object]");
			
			[self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
								  withRowAnimation:UITableViewRowAnimationFade];
			break;
			
		case NSFetchedResultsChangeUpdate:
			NSLog(@"NSFetchedResultsChangeUpdate[Object]");
			
			// There is a bug in NSFetchedResultsController that we need to workaround.
			
			BOOL didDeleteSection = [deletedSections count] > 0;
			BOOL didInsertSection = [insertedSections count] > 0;
			
			if (didDeleteSection && didInsertSection)
			{
				NSLog(@"didDeleteSection && didInsertSection");
				
				// The user is the only one in their old section (which is why its being deleted),
				// and is the only one in their new section (which is why its being inserted).
				// 
				// This should work just fine without us having to do anything.
			}
			else if (didInsertSection)
			{
				NSLog(@"didInsertSection");
				
				// Description of problem:
				// 
				// A user changes their presence.
				// They were previously no other user in their new presence.
				// So the new presence section is being inserted.
				// And the user's index path is the same as what it used to be.
				// 
				// Example:
				// 
				// There was previously only one sections displayed: offline.
				// The user at the TOP of the offline list (indexPath=[0,0]) logs in.
				// So the available section is inserted,
				// and the user moves to the available section (indexPath=[0,0]).
				// 
				// The previous indexPath and new indexPath is the same.
				// 
				// When this occurs (change in section, but indexPath remains the same),
				// the frc sends a ChangeUpdate instead of a MoveUpdate.
				// 
				// Unless we tell the tableView to reload the section where the user is going,
				// the tableView crashes with an array out of bounds exception.
				
				[self.tableView reloadSections:insertedSections
				              withRowAnimation:UITableViewRowAnimationNone];
			}
			else if (didDeleteSection)
			{
				NSLog(@"didDeleteSection");
				
				// Description of problem:
				// 
				// A user changes their presence.
				// They were previously the only user in their previous presence.
				// So the previous presence section is being deleted.
				// And the user's index path is the same as what it used to be.
				// 
				// Example:
				// 
				// There was previously only two sections displayed: available and offline.
				// There was only a single available user (indexPath=[0,0]).
				// The available user logs out.
				// The user will now be positioned at the TOP of the offline section (indexPath=[0,0]).
				// So the available section was deleted, and the user moved to the TOP of the offline section.
				// The previous indexPath and new indexPath are the same.
				// 
				// When this occurs (change in section, but indexPath remains the same),
				// the frc sends a ChangeUpdate instead of a MoveUpdate.
				// 
				// Unless we tell the tableView to reload the section where the user is going,
				// the tableView crashes with an error about how we didn't add or delete anyone from the offline
				// section, but the number of users in the section is now different.
				
				// Todo...
			}
			else
			{
				[self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
									  withRowAnimation:UITableViewRowAnimationNone];
			}
			
			break;
			
		case NSFetchedResultsChangeMove:
			NSLog(@"NSFetchedResultsChangeMove[Object]");
			
			[self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
								  withRowAnimation:UITableViewRowAnimationFade];
			
			[self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath]
								  withRowAnimation:UITableViewRowAnimationFade];
			break;
	}
}

- (void)controller:(NSFetchedResultsController *)controller
  didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex
     forChangeType:(NSFetchedResultsChangeType)type
{
	if(![self isViewLoaded]) return;
	
	switch(type)
	{
		case NSFetchedResultsChangeInsert:
			NSLog(@"NSFetchedResultsChangeInsert[Section]");
			
			[self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex]
			              withRowAnimation:UITableViewRowAnimationFade];
			
			[insertedSections addIndex:sectionIndex];
			
			break;
            
		case NSFetchedResultsChangeDelete:
			NSLog(@"NSFetchedResultsChangeDelete[Section]");
			
			[self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex]
			              withRowAnimation:UITableViewRowAnimationFade];
			
			[deletedSections addIndex:sectionIndex];
			
			break;
	}
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
	if(![self isViewLoaded]) return;
	
	NSLog(@"controllerDidChangeContent");
	
	[deletedSections removeAllIndexes];
	[insertedSections removeAllIndexes];
	
	[self.tableView endUpdates];
} 

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Memory management
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
}

- (void)dealloc
{
	[fetchedResultsController release];
	[managedObjectContext release];
	
    [super dealloc];
}

@end
