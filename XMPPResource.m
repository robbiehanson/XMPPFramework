#import "XMPPResource.h"
#import "XMPPJID.h"
#import "XMPPUser.h"
#import "XMPPIQ.h"
#import "XMPPPresence.h"


@implementation XMPPResource

- (id)initWithPresence:(XMPPPresence *)aPresence
{
	if(self = [super init])
	{
		jid = [[aPresence from] retain];
		presence = [aPresence retain];
		
		presenceReceived = [[NSDate alloc] init];
	}
	return self;
}

- (XMPPJID *)jid
{
	return jid;
}

- (XMPPPresence *)presence
{
	return presence;
}

- (NSDate *)presenceReceived
{
	return presenceReceived;
}

- (void)updateWithPresence:(XMPPPresence *)aPresence
{
	[presence release];
	presence = [aPresence retain];
	
	[presenceReceived release];
	presenceReceived = [[NSDate alloc] init];
}

- (NSComparisonResult)compare:(XMPPResource *)another
{
	int mp = [[self presence] priority];
	int ap = [[another presence] priority];
	
	if(mp < ap)
		return NSOrderedDescending;
	if(mp > ap)
		return NSOrderedAscending;
	
	// Priority is the same.
	// Determine who is more available based on their show.
	int ms = [[self presence] intShow];
	int as = [[another presence] intShow];
	
	if(ms < as)
		return NSOrderedDescending;
	if(ms > as)
		return NSOrderedAscending;
	
	// Priority and Show are the same.
	// Determine based on who was the last to receive a presence element.
	NSDate *mr = [self presenceReceived];
	NSDate *ar = [another presenceReceived];
	
	return [mr compare:ar];
}

@end
