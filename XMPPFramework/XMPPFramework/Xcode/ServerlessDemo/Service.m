#import "Service.h"


@implementation Service

@dynamic serviceType;
@dynamic serviceName;
@dynamic serviceDomain;
@dynamic serviceDescription;

@dynamic status;
@dynamic statusMessage;
@dynamic firstName;
@dynamic lastName;
@dynamic nickname;
@dynamic displayName;
@dynamic lastResolvedAddress;

@dynamic messages;

@dynamic statusType;

- (StatusType)statusType
{
	switch ([[self status] intValue])
	{
		case StatusAvailable: return StatusAvailable;
		case StatusDND      : return StatusDND;
		default             : return StatusOffline;
	}
}

- (void)setStatusType:(StatusType)type
{
	switch (type)
	{
		case StatusAvailable:
			[self setStatus:[NSNumber numberWithInt:StatusAvailable]];
			break;
			
		case StatusDND:
			[self setStatus:[NSNumber numberWithInt:StatusDND]];
			break;
		
		default:
			[self setStatus:[NSNumber numberWithInt:StatusOffline]];
			break;
	}
}

+ (NSString *)statusTxtTitleForStatusType:(StatusType)type
{
	switch (type)
	{
		case StatusAvailable: return @"avail";
		case StatusDND      : return @"dnd";
		default             : return @"offline";
	}
}

+ (NSString *)statusDisplayTitleForStatusType:(StatusType)type
{
	switch (type)
	{
		case StatusAvailable: return @"Available";
		case StatusDND      : return @"Away";
		default             : return @"Offline";
	}
}

+ (StatusType)statusTypeForStatusTxtTitle:(NSString *)statusTxtTitle
{
	if ([statusTxtTitle caseInsensitiveCompare:@"avail"] == NSOrderedSame)
	{
		return StatusAvailable;
	}
	if ([statusTxtTitle caseInsensitiveCompare:@"dnd"] == NSOrderedSame)
	{
		return StatusDND;
	}
	
	return StatusOffline;
}

- (NSString *)statusTxtTitle
{
	return [[self class] statusTxtTitleForStatusType:[self statusType]];
}

- (NSString *)statusDisplayTitle
{
	return [[self class] statusDisplayTitleForStatusType:[self statusType]];
}

- (void)updateDisplayName
{
	NSString *nickname  = self.nickname;
	NSString *firstName = self.firstName;
	NSString *lastName  = self.lastName;
	
	// If the firstName or lastName isn't properly entered, we shouldn't have goofy leading/trailing whitespace.
	
	if([nickname length] > 0)
	{
		self.displayName = nickname;
	}
	else if([firstName length] > 0)
	{
		if([lastName length] > 0)
			self.displayName = [firstName stringByAppendingFormat:@" %@", lastName];
		else
			self.displayName = firstName;
	}
	else if([lastName length] > 0)
	{
		self.displayName = lastName;
	}
	else
	{
		self.displayName = self.serviceName;
	}
}

- (NSUInteger)numberOfUnreadMessages
{
	NSEntityDescription *entity = [NSEntityDescription entityForName:@"Message"
	                                          inManagedObjectContext:self.managedObjectContext];
	
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"service == %@ AND read == NO", self];
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	[fetchRequest setEntity:entity];
	[fetchRequest setPredicate:predicate];
	
    NSError *error = nil;
	NSUInteger count = 0;
    
	count = [self.managedObjectContext countForFetchRequest:fetchRequest error:&error];
	
	
	if (error)
    {
		NSLog(@"Error getting unread count: %@, %@", error, [error userInfo]);
	}
    
	return count;
}


@end
