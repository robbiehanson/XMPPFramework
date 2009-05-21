#import "XMPPResource.h"
#import "XMPPJID.h"
#import "XMPPUser.h"
#import "XMPPIQ.h"
#import "XMPPPresence.h"


@implementation XMPPResource

- (id)initWithPresence:(XMPPPresence *)aPresence
{
	if((self = [super init]))
	{
		jid = [[aPresence from] retain];
		presence = [aPresence retain];
		
		presenceReceived = [[NSDate alloc] init];
	}
	return self;
}

- (void)dealloc
{
	[jid release];
	[presence release];
	[presenceReceived release];
	[super dealloc];
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
		return [NSDistantObject proxyWithLocal:self connection:[encoder connection]];
}
#endif

- (id)initWithCoder:(NSCoder *)coder
{
	if((self = [super init]))
	{
		if([coder allowsKeyedCoding])
		{
			jid              = [[coder decodeObjectForKey:@"jid"] retain];
			presence         = [[coder decodeObjectForKey:@"presence"] retain];
			presenceReceived = [[coder decodeObjectForKey:@"presenceReceived"] retain];
		}
		else
		{
			jid              = [[coder decodeObject] retain];
			presence         = [[coder decodeObject] retain];
			presenceReceived = [[coder decodeObject] retain];
		}
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	if([coder allowsKeyedCoding])
	{
		[coder encodeObject:jid              forKey:@"jid"];
		[coder encodeObject:presence         forKey:@"presence"];
		[coder encodeObject:presenceReceived forKey:@"presenceReceived"];
	}
	else
	{
		[coder encodeObject:jid];
		[coder encodeObject:presence];
		[coder encodeObject:presenceReceived];
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

- (NSDate *)presenceReceived
{
	return presenceReceived;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Update Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)updateWithPresence:(XMPPPresence *)aPresence
{
	[presence release];
	presence = [aPresence retain];
	
	[presenceReceived release];
	presenceReceived = [[NSDate alloc] init];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Comparison Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark NSObject Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#if MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_4
- (unsigned)hash
{
	return [jid hash];
}
#else
- (NSUInteger)hash
{
	return [jid hash];
}
#endif

- (BOOL)isEqual:(id)anObject
{
	if([anObject isMemberOfClass:[self class]])
	{
		XMPPResource *another = (XMPPResource *)anObject;
		
		return [jid isEqual:[another jid]];
	}
	
	return NO;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"XMPPResource: %@", [jid full]];
}

@end
