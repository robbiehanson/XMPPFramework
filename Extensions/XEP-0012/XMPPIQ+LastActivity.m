//
//  XMPPIQ+LastActivity.m
//  XEP-0012
//
//  Created by Daniel Rodríguez Troitiño on 1/26/2013.
//

#import "XMPPIQ+LastActivity.h"

#import "XMPP.h"

NSString *const XMPPLastActivityNamespace = @"jabber:iq:last";

@implementation XMPPIQ (LastActivity)

+ (instancetype)lastActivityQueryTo:(XMPPJID *)jid
{
	NSXMLElement *query = [[NSXMLElement alloc] initWithName:@"query" xmlns:XMPPLastActivityNamespace];
	return [[self alloc] initWithType:@"get" to:jid elementID:[XMPPStream generateUUID] child:query];
}

+ (instancetype)lastActivityResponseTo:(XMPPIQ *)request withSeconds:(NSUInteger)seconds
{
	return [self lastActivityResponseTo:request withSeconds:seconds status:nil];
}

+ (instancetype)lastActivityResponseTo:(XMPPIQ *)request withSeconds:(NSUInteger)seconds status:(NSString *)status
{
	NSXMLElement *query = [[NSXMLElement alloc] initWithName:@"query" xmlns:XMPPLastActivityNamespace];
	if (status && [status length] > 0)
	{
		[query setStringValue:status];
	}

	return [[self alloc] initWithType:@"result" to:request.from elementID:request.elementID child:query];
}

+ (instancetype)lastActivityResponseForbiddenTo:(XMPPIQ *)request
{
	NSXMLElement *reason = [[NSXMLElement alloc] initWithName:@"forbidden" xmlns:@"urn:ietf:params:xml:ns:xmpp-stanzas"];
	NSXMLElement *error = [[NSXMLElement alloc] initWithName:@"error"];
	[error addAttributeWithName:@"type" stringValue:@"auth"];
	[error addChild:reason];

	return [[self alloc] initWithType:@"error" to:request.from elementID:request.elementID child:error];
}

@end