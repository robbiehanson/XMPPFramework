#import "XMPPMessageArchiving_Contact_CoreDataObject.h"


@interface XMPPMessageArchiving_Contact_CoreDataObject ()

@property (nonatomic, strong) XMPPJID * primitiveBareJid;
@property (nonatomic, strong) NSString * primitiveBareJidStr;

@end


@implementation XMPPMessageArchiving_Contact_CoreDataObject

@dynamic bareJid, primitiveBareJid;
@dynamic bareJidStr, primitiveBareJidStr;
@dynamic mostRecentMessageTimestamp;
@dynamic mostRecentMessageBody;
@dynamic mostRecentMessageOutgoing;
@dynamic streamBareJidStr;

#pragma mark Transient bareJid

- (XMPPJID *)bareJid
{
	// Create and cache on demand
	
	[self willAccessValueForKey:@"bareJid"];
	XMPPJID *tmp = self.primitiveBareJid;
	[self didAccessValueForKey:@"bareJid"];
	
	if (tmp == nil)
	{
		NSString *bareJidStr = self.bareJidStr;
		if (bareJidStr)
		{
			tmp = [XMPPJID jidWithString:bareJidStr];
			self.primitiveBareJid = tmp;
		}
	}
	
	return tmp;
}

- (void)setBareJid:(XMPPJID *)bareJid
{
	if ([self.bareJid isEqualToJID:bareJid options:XMPPJIDCompareBare])
	{
		return; // No change
	}
	
	[self willChangeValueForKey:@"bareJid"];
	[self willChangeValueForKey:@"bareJidStr"];
	
	self.primitiveBareJid = [bareJid bareJID];
	self.primitiveBareJidStr = [bareJid bare];
	
	[self didChangeValueForKey:@"bareJid"];
	[self didChangeValueForKey:@"bareJidStr"];
}

- (void)setBareJidStr:(NSString *)bareJidStr
{
	if ([self.bareJidStr isEqualToString:bareJidStr])
	{
		return; // No change
	}
	
	[self willChangeValueForKey:@"bareJid"];
	[self willChangeValueForKey:@"bareJidStr"];
	
	XMPPJID *bareJid = [[XMPPJID jidWithString:bareJidStr] bareJID];
	
	self.primitiveBareJid = bareJid;
	self.primitiveBareJidStr = [bareJid bare];
	
	[self didChangeValueForKey:@"bareJid"];
	[self didChangeValueForKey:@"bareJidStr"];
}

#pragma mark Hooks

- (void)willInsertObject
{
	// If you extend XMPPMessageArchiving_Contact_CoreDataObject,
	// you can override this method to use as a hook to set your own custom properties.
}

- (void)didUpdateObject
{
	// If you extend XMPPMessageArchiving_Contact_CoreDataObject,
	// you can override this method to use as a hook to update your own custom properties.
}

@end
