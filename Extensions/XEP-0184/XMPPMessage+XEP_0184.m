#import "XMPPMessage+XEP_0184.h"
#import "NSXMLElement+XMPP.h"


@implementation XMPPMessage (XEP_0184)

- (BOOL)hasReceiptRequest
{
	NSXMLElement *receiptRequest = [self xmpp_elementForName:@"request" xmlns:@"urn:xmpp:receipts"];
	
	return (receiptRequest != nil);
}

- (BOOL)hasReceiptResponse
{
	NSXMLElement *receiptResponse = [self xmpp_elementForName:@"received" xmlns:@"urn:xmpp:receipts"];
	
	return (receiptResponse != nil);
}

- (NSString *)receiptResponseID
{
	NSXMLElement *receiptResponse = [self xmpp_elementForName:@"received" xmlns:@"urn:xmpp:receipts"];
	
	return [receiptResponse xmpp_attributeStringValueForName:@"id"];
}

- (XMPPMessage *)generateReceiptResponse
{
	// Example:
	// 
	// <message to="juliet">
	//   <received xmlns="urn:xmpp:receipts" id="ABC-123"/>
	// </message>
	
	NSXMLElement *received = [NSXMLElement xmpp_elementWithName:@"received" xmlns:@"urn:xmpp:receipts"];
	
	NSXMLElement *message = [NSXMLElement elementWithName:@"message"];
	
	NSString *to = [self fromStr];
	if (to)
	{
		[message xmpp_addAttributeWithName:@"to" stringValue:to];
	}
	
	NSString *msgid = [self elementID];
	if (msgid)
	{
		[received xmpp_addAttributeWithName:@"id" stringValue:msgid];
	}
	
	[message addChild:received];
	
	return [[self class] messageFromElement:message];
}


- (void)addReceiptRequest
{
    NSXMLElement *receiptRequest = [NSXMLElement xmpp_elementWithName:@"request" xmlns:@"urn:xmpp:receipts"];
    [self addChild:receiptRequest];
}

@end
