#import "XMPPMessageArchiving_Message_CoreDataObject.h"


@interface XMPPMessageArchiving_Message_CoreDataObject ()

@property(nonatomic,strong) XMPPMessage * primitiveMessage;
@property(nonatomic,strong) NSString * primitiveMessageStr;

@property(nonatomic,strong) XMPPJID * primitiveBareJid;
@property(nonatomic,strong) NSString * primitiveBareJidStr;

@end

@implementation XMPPMessageArchiving_Message_CoreDataObject

@dynamic message, primitiveMessage;
@dynamic messageStr, primitiveMessageStr;
@dynamic bareJid, primitiveBareJid;
@dynamic bareJidStr, primitiveBareJidStr;
@dynamic body;
@dynamic thread;
@dynamic outgoing;
@dynamic composing;
@dynamic timestamp;
@dynamic streamBareJidStr;

#pragma mark Transient message

- (XMPPMessage *)message
{
	// Create and cache on demand
	
	[self willAccessValueForKey:@"message"];
	XMPPMessage *message = self.primitiveMessage;
	[self didAccessValueForKey:@"message"];
	
	if (message == nil)
	{
		NSString *messageStr = self.messageStr;
		if (messageStr)
		{
			NSXMLElement *element = [[NSXMLElement alloc] initWithXMLString:messageStr error:nil];
			message = [XMPPMessage messageFromElement:element];
			self.primitiveMessage = message;
		}
    }
	
    return message;
}

- (void)setMessage:(XMPPMessage *)message
{
	[self willChangeValueForKey:@"message"];
	[self willChangeValueForKey:@"messageStr"];
	
	self.primitiveMessage = message;
	self.primitiveMessageStr = [message compactXMLString];
	
	[self didChangeValueForKey:@"message"];
	[self didChangeValueForKey:@"messageStr"];
}

- (void)setMessageStr:(NSString *)messageStr
{
	[self willChangeValueForKey:@"message"];
	[self willChangeValueForKey:@"messageStr"];
	
	NSXMLElement *element = [[NSXMLElement alloc] initWithXMLString:messageStr error:nil];
	self.primitiveMessage = [XMPPMessage messageFromElement:element];
	self.primitiveMessageStr = messageStr;
	
	[self didChangeValueForKey:@"message"];
	[self didChangeValueForKey:@"messageStr"];
}

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

#pragma mark Convenience properties

- (BOOL)isOutgoing
{
	return [self.outgoing boolValue];
}

- (void)setIsOutgoing:(BOOL)flag
{
	self.outgoing = @(flag);
}

- (BOOL)isComposing
{
	return [self.composing boolValue];
}

- (void)setIsComposing:(BOOL)flag
{
	self.composing = @(flag);
}

#pragma mark Hooks

- (void)willInsertObject
{
	// If you extend XMPPMessageArchiving_Message_CoreDataObject,
	// you can override this method to use as a hook to set your own custom properties.
}

- (void)didUpdateObject
{
	// If you extend XMPPMessageArchiving_Message_CoreDataObject,
	// you can override this method to use as a hook to set your own custom properties.
}

@end
