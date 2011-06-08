#import "XMPPMessage.h"
#import "XMPPJID.h"
#import "NSXMLElement+XMPP.h"

#import <objc/runtime.h>


@implementation XMPPMessage

+ (void)initialize
{
	// We use the object_setClass method below to dynamically change the class from a standard NSXMLElement.
	// The size of the two classes is expected to be the same.
	// 
	// If a developer adds instance methods to this class, bad things happen at runtime that are very hard to debug.
	// This check is here to aid future developers who may make this mistake.
	// 
	// For Fearless And Experienced Objective-C Developers:
	// It may be possible to support adding instance variables to this class if you seriously need it.
	// To do so, try realloc'ing self after altering the class, and then initialize your variables.
	
	size_t superSize = class_getInstanceSize([NSXMLElement class]);
	size_t ourSize   = class_getInstanceSize([XMPPMessage class]);
	
	if (superSize != ourSize)
	{
		NSLog(@"Adding instance variables to XMPPMessage is not currently supported!");
		exit(15);
	}
}

+ (XMPPMessage *)messageFromElement:(NSXMLElement *)element
{
	object_setClass(element, [XMPPMessage class]);
	
	return (XMPPMessage *)element;
}

+ (XMPPMessage *)message
{
	return [[[XMPPMessage alloc] init] autorelease];
}

- (id)init
{
	self = [super initWithName:@"message"];
	return self;
}

- (BOOL)isChatMessage
{
	return [[[self attributeForName:@"type"] stringValue] isEqualToString:@"chat"];
}

- (BOOL)isChatMessageWithBody
{
	if([self isChatMessage])
	{
		return [self isMessageWithBody];
	}
	
	return NO;
}

- (BOOL)isErrorMessage {
    return [[[self attributeForName:@"type"] stringValue] isEqualToString:@"error"];
}

- (NSError *)errorMessage {
    if (![self isErrorMessage]) {
        return nil;
    }
    
    NSXMLElement *error = [self elementForName:@"error"];
    return [NSError errorWithDomain:@"urn:ietf:params:xml:ns:xmpp-stanzas" 
                               code:[error attributeIntValueForName:@"code"] 
                           userInfo:[NSDictionary dictionaryWithObject:[error compactXMLString] forKey:NSLocalizedDescriptionKey]];

}

- (BOOL)isMessageWithBody {
    NSString *body = [[self elementForName:@"body"] stringValue];
    
    return ((body != nil) && ([body length] > 0));
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XEP-0184: Message Receipts
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)hasReceiptRequest
{
	NSXMLElement *receiptRequest = [self elementForName:@"request" xmlns:@"urn:xmpp:receipts"];
	
	return (receiptRequest != nil);
}

- (BOOL)hasReceiptResponse
{
	NSXMLElement *receiptResponse = [self elementForName:@"received" xmlns:@"urn:xmpp:receipts"];
	
	return (receiptResponse != nil);
}

- (NSString *)extractReceiptResponseID
{
	NSXMLElement *receiptResponse = [self elementForName:@"received" xmlns:@"urn:xmpp:receipts"];
	
	return [receiptResponse attributeStringValueForName:@"id"];
}

- (XMPPMessage *)generateReceiptResponse
{
	// Example:
	// 
	// <message to="juliet">
	//   <received xmlns="urn:xmpp:receipts" id="ABC-123"/>
	// </message>
	
	NSXMLElement *received = [NSXMLElement elementWithName:@"received" xmlns:@"urn:xmpp:receipts"];
	
	NSXMLElement *message = [NSXMLElement elementWithName:@"message"];
	
	NSString *to = [self fromStr];
	if(to)
	{
		[message addAttributeWithName:@"to" stringValue:to];
	}
	
	NSString *msgid = [self elementID];
	if(msgid)
	{
		[received addAttributeWithName:@"id" stringValue:msgid];
	}
	
	[message addChild:received];
	
	return [[self class] messageFromElement:message];
}

@end
