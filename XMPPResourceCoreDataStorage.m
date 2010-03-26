#import "XMPP.h"
#import "XMPPRosterCoreDataStorage.h"
#import "XMPPUserCoreDataStorage.h"
#import "XMPPResourceCoreDataStorage.h"


@implementation XMPPResourceCoreDataStorage

@dynamic jid;      // Implementation below
@dynamic presence; // Implementation below
@dynamic priority; // Implementation below
@dynamic intShow;  // Implementation below

@dynamic jidStr;
@dynamic presenceStr;
@dynamic type;
@dynamic show;
@dynamic status;

@dynamic presenceDate;

@dynamic priorityNum;
@dynamic showNum;

@dynamic user;

- (XMPPJID *)jid
{
	return [XMPPJID jidWithString:[self jidStr]];
}

- (void)setJid:(XMPPJID *)jid
{
	self.jidStr = [jid bare];
}

- (XMPPPresence *)presence
{
	[self willAccessValueForKey:@"presence"];
    XMPPPresence *presence = [self primitiveValueForKey:@"presence"];
    [self didAccessValueForKey:@"presence"];
	
    if (presence == nil)
    {
		NSString *presenceStr = self.presenceStr;
		if (presenceStr != nil)
		{
			NSXMLElement *element = [[NSXMLElement alloc] initWithXMLString:presenceStr error:nil];
			
			presence = [XMPPPresence presenceFromElement:element];
			[self setPrimitiveValue:presence forKey:@"presence"];
			
			[element release];
		}
    }
	
    return presence;
}

- (void)setPresence:(XMPPPresence *)newPresence
{
	[self willChangeValueForKey:@"presence"];
	[self setPrimitiveValue:newPresence forKey:@"presence"];
	[self didChangeValueForKey:@"presence"];
    
	self.presenceStr = [newPresence compactXMLString];
}

- (int)priority
{
	return [[self priorityNum] intValue];
}

- (void)setPriority:(int)priority
{
	self.priorityNum = [NSNumber numberWithInt:priority];
}

- (int)intShow
{
	return [[self showNum] intValue];
}

- (void)setIntShow:(int)intShow
{
	self.showNum = [NSNumber numberWithInt:intShow];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Creation & Updates
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (id)insertInManagedObjectContext:(NSManagedObjectContext *)moc withPresence:(XMPPPresence *)presence
{
	XMPPJID *jid = [presence from];
	
	if (jid == nil)
	{
		NSLog(@"XMPPResourceCoreDataStorage: invalid presence (missing or invalid jid): %@", presence);
		return nil;
	}
	
	XMPPResourceCoreDataStorage *newResource;
	newResource = [NSEntityDescription insertNewObjectForEntityForName:@"XMPPResourceCoreDataStorage"
	                                            inManagedObjectContext:moc];
	
	[newResource updateWithPresence:presence];
	
	return newResource;
}

- (void)updateWithPresence:(XMPPPresence *)presence
{
	XMPPJID *jid = [presence from];
	
	if (jid == nil)
	{
		NSLog(@"XMPPResourceCoreDataStorage: invalid presence (missing or invalid jid): %@", presence);
		return;
	}
	
	self.jid = jid;
	self.presence = presence;
	
	self.priority = [presence priority];
	self.intShow = [presence intShow];
	
	self.type = [presence type];
	self.show = [presence show];
	self.status = [presence status];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPResource Protocol
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSComparisonResult)compare:(id <XMPPResource>)another
{
	XMPPPresence *mp = [self presence];
	XMPPPresence *ap = [another presence];
	
	int mpp = [mp priority];
	int app = [ap priority];
	
	if(mpp < app)
		return NSOrderedDescending;
	if(mpp > app)
		return NSOrderedAscending;
	
	// Priority is the same.
	// Determine who is more available based on their show.
	int mps = [mp intShow];
	int aps = [ap intShow];
	
	if(mps < aps)
		return NSOrderedDescending;
	if(mps > aps)
		return NSOrderedAscending;
	
	// Priority and Show are the same.
	// Determine based on who was the last to receive a presence element.
	NSDate *mpd = [self presenceDate];
	NSDate *apd = [another presenceDate];
	
	return [mpd compare:apd];
}

@end
