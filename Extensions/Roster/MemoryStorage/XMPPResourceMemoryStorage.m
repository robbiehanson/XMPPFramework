#import "XMPP.h"
#import "XMPPElement+Delay.h"
#import "XMPPRosterMemoryStoragePrivate.h"

@implementation XMPPResourceMemoryStorage

- (id)initWithPresence:(XMPPPresence *)aPresence
{
	if((self = [super init]))
	{
		jid = [[aPresence from] retain];
		presence = [aPresence retain];
		
		presenceDate = [[presence delayedDeliveryDate] retain];
		if (presenceDate == nil)
		{
			presenceDate = [[NSDate alloc] init];
		}
	}
	return self;
}

- (void)dealloc
{
	[jid release];
	[presence release];
	[presenceDate release];
	[super dealloc];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Copying
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (id)copyWithZone:(NSZone *)zone
{
	XMPPResourceMemoryStorage *deepCopy = [[XMPPResourceMemoryStorage alloc] init];
	
	deepCopy->jid = [jid copy];
	deepCopy->presence = [presence retain]; // No need to bother with a copy we don't alter presence
	deepCopy->presenceDate = [presenceDate copy];
	
	return deepCopy;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Encoding, Decoding
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#if ! TARGET_OS_IPHONE
- (id)replacementObjectForPortCoder:(NSPortCoder *)encoder
{
	if([encoder isBycopy])
		return self;
	else
		return [super replacementObjectForPortCoder:encoder];
	//	return [NSDistantObject proxyWithLocal:self connection:[encoder connection]];
}
#endif

- (id)initWithCoder:(NSCoder *)coder
{
	if((self = [super init]))
	{
		if([coder allowsKeyedCoding])
		{
			jid          = [[coder decodeObjectForKey:@"jid"] retain];
			presence     = [[coder decodeObjectForKey:@"presence"] retain];
			presenceDate = [[coder decodeObjectForKey:@"presenceDate"] retain];
		}
		else
		{
			jid          = [[coder decodeObject] retain];
			presence     = [[coder decodeObject] retain];
			presenceDate = [[coder decodeObject] retain];
		}
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	if([coder allowsKeyedCoding])
	{
		[coder encodeObject:jid          forKey:@"jid"];
		[coder encodeObject:presence     forKey:@"presence"];
		[coder encodeObject:presenceDate forKey:@"presenceDate"];
	}
	else
	{
		[coder encodeObject:jid];
		[coder encodeObject:presence];
		[coder encodeObject:presenceDate];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Standard Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (XMPPJID *)jid
{
	return jid;
}

- (XMPPPresence *)presence
{
	return presence;
}

- (NSDate *)presenceDate
{
	return presenceDate;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Update Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)updateWithPresence:(XMPPPresence *)aPresence
{
	[presence release];
	presence = [aPresence retain];
	
	[presenceDate release];
	presenceDate = [[presence delayedDeliveryDate] retain];
	if (presenceDate == nil)
	{
		presenceDate = [[NSDate alloc] init];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Comparison Methods
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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark NSObject Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSUInteger)hash
{
	return [jid hash];
}

- (BOOL)isEqual:(id)anObject
{
	if([anObject isMemberOfClass:[self class]])
	{
		XMPPResourceMemoryStorage *another = (XMPPResourceMemoryStorage *)anObject;
		
		return [jid isEqual:[another jid]];
	}
	
	return NO;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"XMPPResource: %@", [jid full]];
}

@end
