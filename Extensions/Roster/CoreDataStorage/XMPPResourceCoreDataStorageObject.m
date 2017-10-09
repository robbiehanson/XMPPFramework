#import "XMPP.h"
#import "XMPPLogging.h"
#import "XMPPRosterCoreDataStorage.h"
#import "XMPPUserCoreDataStorageObject.h"
#import "XMPPResourceCoreDataStorageObject.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

// Log levels: off, error, warn, info, verbose
#if DEBUG
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#else
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

@interface XMPPResourceCoreDataStorageObject (CoreDataGeneratedPrimitiveAccessors)
- (NSDate *)primitivePresenceDate;
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPResourceCoreDataStorageObject

@dynamic jid;      // Implementation below
@dynamic presence; // Implementation below
@dynamic priority; // Implementation below
@dynamic intShow;  // Implementation below

@dynamic jidStr;
@dynamic presenceStr;

@dynamic streamBareJidStr;

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
	self.jidStr = [jid full];
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

- (NSInteger)priority
{
	return [[self priorityNum] intValue];
}

- (void)setPriority:(NSInteger)priority
{
	self.priorityNum = @(priority);
}

- (XMPPPresenceShow)intShow
{
	return [[self showNum] intValue];
}

- (void)setIntShow:(XMPPPresenceShow)intShow
{
	self.showNum = @(intShow);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Compiler Workarounds
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#if TARGET_OS_IPHONE && !TARGET_IPHONE_SIMULATOR

/**
 * This method is here to quiet the compiler.
 * Without it the compiler complains that this method is not implemented as required by the protocol.
 * This only seems to be a problem when compiling for the device.
**/
- (NSDate *)presenceDate 
{
    NSDate * tmpValue;
    
    [self willAccessValueForKey:@"presenceDate"];
    tmpValue = [self primitivePresenceDate];
    [self didAccessValueForKey:@"presenceDate"];
    
    return tmpValue;
}

#endif

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Creation & Updates
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (id)insertInManagedObjectContext:(NSManagedObjectContext *)moc
                      withPresence:(XMPPPresence *)presence
                  streamBareJidStr:(NSString *)streamBareJidStr
{
	XMPPJID *jid = [presence from];
	
	if (jid == nil)
	{
		XMPPLogWarn(@"%@: %@ - Invalid presence (missing or invalid jid): %@", [self class], THIS_METHOD, presence);
		return nil;
	}
	
	XMPPResourceCoreDataStorageObject *newResource;
	newResource = [NSEntityDescription insertNewObjectForEntityForName:@"XMPPResourceCoreDataStorageObject"
	                                            inManagedObjectContext:moc];
	
	newResource.streamBareJidStr = streamBareJidStr;
	
	[newResource updateWithPresence:presence];
	
	return newResource;
}

- (void)updateWithPresence:(XMPPPresence *)presence
{
	XMPPJID *jid = [presence from];
	
	if (jid == nil)
	{
		XMPPLogWarn(@"%@: %@ - Invalid presence (missing or invalid jid): %@", [self class], THIS_METHOD, presence);
		return;
	}
	
	self.jid = jid;
	self.presence = presence;
	
	self.priority = [presence priority];
	self.intShow = [presence showValue];
	
	self.type = [presence type];
	self.show = [presence show];
	self.status = [presence status];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Comparing
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSComparisonResult)compare:(id <XMPPResource>)another
{
	XMPPPresence *mp = [self presence];
	XMPPPresence *ap = [another presence];
	
	NSInteger mpp = [mp priority];
	NSInteger app = [ap priority];
	
	if(mpp < app)
		return NSOrderedDescending;
	if(mpp > app)
		return NSOrderedAscending;
	
	// Priority is the same.
	// Determine who is more available based on their show.
	XMPPPresenceShow mps = [mp showValue];
	XMPPPresenceShow aps = [ap showValue];
	
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
