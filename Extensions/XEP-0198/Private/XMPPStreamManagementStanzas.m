#import "XMPPStreamManagementStanzas.h"


@implementation XMPPStreamManagementOutgoingStanza

@synthesize awaitingStanzaId = awaitingStanzaId;
@synthesize stanzaId = stanzaId;

/**
 * Use when the stanzaId is unknown, and we are awaiting a stanzaId from the delegate(s).
**/
- (instancetype)initAwaitingStanzaId
{
	if ((self = [super init]))
	{
		awaitingStanzaId = YES;
	}
	return self;
}

/**
 * Use when the stanzaId is known, meaning we are NOT awaiting a stanzaId from the delegate(s).
 * The stanzaId may be nil.
**/
- (instancetype)initWithStanzaId:(id)inStanzaId
{
	if ((self = [super init]))
	{
		stanzaId = inStanzaId;
		awaitingStanzaId = NO;
	}
	return self;
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)zone
{
	XMPPStreamManagementOutgoingStanza *copy = [[XMPPStreamManagementOutgoingStanza alloc] init];
	copy->awaitingStanzaId = awaitingStanzaId;
	copy->stanzaId = stanzaId;
	
	return copy;
}

/* NSCoding */

- (id)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]))
	{
		awaitingStanzaId = [decoder decodeBoolForKey:@"awaitingStanzaId"];
		stanzaId = [decoder decodeObjectForKey:@"stanzaId"];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeBool:awaitingStanzaId forKey:@"awaitingStanzaId"];
	[coder encodeObject:stanzaId forKey:@"stanzaId"];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPStreamManagementIncomingStanza

@synthesize stanzaId = stanzaId;
@synthesize isHandled = isHandled;

- (instancetype)initWithStanzaId:(id)inStanzaId isHandled:(BOOL)inIsHandled
{
	if ((self = [super init]))
	{
		stanzaId = inStanzaId;
		isHandled = inIsHandled;
	}
	return self;
}

@end
