//
//  XMPPIQ+LastActivity.m
//  XEP-0012
//
//  Created by Daniel Rodríguez Troitiño on 1/26/2013.
//

#import "XMPPIQ+LastActivity.h"

#import "XMPP.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

NSString *const XMPPLastActivityNamespace = @"jabber:iq:last";

@implementation XMPPIQ (LastActivity)

+ (XMPPIQ *)lastActivityQueryTo:(XMPPJID *)jid
{
	NSXMLElement *query = [[NSXMLElement alloc] initWithName:@"query" xmlns:XMPPLastActivityNamespace];
	return [[self alloc] initWithType:@"get" to:jid elementID:[XMPPStream generateUUID] child:query];
}

+ (XMPPIQ *)lastActivityResponseToIQ:(XMPPIQ *)request withSeconds:(NSUInteger)seconds
{
	return [self lastActivityResponseToIQ:request withSeconds:seconds status:nil];
}

+ (XMPPIQ *)lastActivityResponseToIQ:(XMPPIQ *)request withSeconds:(NSUInteger)seconds status:(NSString *)status
{
	NSXMLElement *query = [[NSXMLElement alloc] initWithName:@"query" xmlns:XMPPLastActivityNamespace];
    [query addAttributeWithName:@"seconds" stringValue:[NSString stringWithFormat:@"%lu", (unsigned long)seconds]];
	if (status && [status length] > 0)
	{
		[query setStringValue:status];
	}
    
	return [[self alloc] initWithType:@"result" to:request.from elementID:request.elementID child:query];
}

+ (XMPPIQ *)lastActivityResponseForbiddenToIQ:(XMPPIQ *)request
{
	NSXMLElement *reason = [[NSXMLElement alloc] initWithName:@"forbidden" xmlns:@"urn:ietf:params:xml:ns:xmpp-stanzas"];
	NSXMLElement *error = [[NSXMLElement alloc] initWithName:@"error"];
	[error addAttributeWithName:@"type" stringValue:@"auth"];
	[error addChild:reason];
    
	return [[self alloc] initWithType:@"error" to:request.from elementID:request.elementID child:error];
}

- (BOOL)isLastActivityQuery
{
	return nil != [self lastActivityQueryElement];
}

- (NSUInteger)lastActivitySeconds
{
	NSUInteger seconds = NSNotFound;
	NSXMLElement *query = [self lastActivityQueryElement];
	if (query)
	{
		NSXMLNode *attribute = [query attributeForName:@"seconds"];
		if (attribute)
		{
            // Some Servers Return -1 to indicate no activity, so we need to ignore these
            if([query attributeIntegerValueForName:@"seconds"] >= 0)
            {
                seconds = [query attributeUnsignedIntegerValueForName:@"seconds"];
            }
		}
	}
    
	return seconds;
}

- (NSString *)lastActivityUnavailableStatus
{
	NSXMLElement *query = [self lastActivityQueryElement];
	if (query)
	{
		return [query stringValue];
	}
	else
	{
		return nil;
	}
}

- (NSXMLElement *)lastActivityQueryElement
{
	return [self elementForName:@"query" xmlns:XMPPLastActivityNamespace];
}

@end