#import "XMPPMessage+XEP_0184.h"
#import "NSXMLElement+XMPP.h"


@implementation XMPPMessage (XEP_0184)

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

- (NSString *)receiptResponseID
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
	if (to)
	{
		[message addAttributeWithName:@"to" stringValue:to];
	}
	
	NSString *msgid = [self elementID];
	if (msgid)
	{
		[received addAttributeWithName:@"id" stringValue:msgid];
	}
	
	[message addChild:received];
	
	return [[self class] messageFromElement:message];
}


- (void)addReceiptRequest
{
    NSXMLElement *receiptRequest = [NSXMLElement elementWithName:@"request" xmlns:@"urn:xmpp:receipts"];
    [self addChild:receiptRequest];
}

@end
