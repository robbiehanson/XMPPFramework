#import "XMPPMessage+XEP_0333.h"
#import "NSXMLElement+XMPP.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

#define XMLNS_CHAT_MARKERS @"urn:xmpp:chat-markers:0"

#define MARKABLE_NAME @"markable"
#define RECEIVED_NAME @"received"
#define DISPLAYED_NAME @"displayed"
#define ACKNOWLEDGED_NAME @"acknowledged"

@implementation XMPPMessage (XEP_0333)

- (BOOL)hasChatMarker
{
    return ([[self elementsForXmlns:XMLNS_CHAT_MARKERS] count] > 0);
}

- (BOOL)hasMarkableChatMarker
{
    return ([self elementForName:MARKABLE_NAME xmlns:XMLNS_CHAT_MARKERS] != nil);
}

- (BOOL)hasReceivedChatMarker
{
    return ([self elementForName:RECEIVED_NAME xmlns:XMLNS_CHAT_MARKERS] != nil);
}

- (BOOL)hasDisplayedChatMarker
{
    return ([self elementForName:DISPLAYED_NAME xmlns:XMLNS_CHAT_MARKERS] != nil);
}

- (BOOL)hasAcknowledgedChatMarker
{
    return ([self elementForName:ACKNOWLEDGED_NAME xmlns:XMLNS_CHAT_MARKERS] != nil);
}

- (NSString *)chatMarker
{
    return [[[self elementsForXmlns:XMLNS_CHAT_MARKERS] lastObject] name];
}

- (NSString *)chatMarkerID
{
    return [[[self elementsForXmlns:XMLNS_CHAT_MARKERS] lastObject] attributeStringValueForName:@"id"];
}

- (NSString *)chatMarkerThread
{
    return [[[self elementsForXmlns:XMLNS_CHAT_MARKERS] lastObject] attributeStringValueForName:@"thread"];
}

- (void)addMarkableChatMarker
{
    NSXMLElement *markableDisplayedMarker = [[NSXMLElement alloc] initWithName:MARKABLE_NAME xmlns:XMLNS_CHAT_MARKERS];
    [self addChild:markableDisplayedMarker];
}

- (void)addReceivedChatMarkerWithID:(NSString *)elementID
{
    NSXMLElement *receivedChatMarker = [[NSXMLElement alloc] initWithName:RECEIVED_NAME xmlns:XMLNS_CHAT_MARKERS];
    [receivedChatMarker addAttributeWithName:@"id" stringValue:elementID];
    
    [self addChild:receivedChatMarker];
}

- (void)addDisplayedChatMarkerWithID:(NSString *)elementID
{
    NSXMLElement *readDisplayedMarker = [[NSXMLElement alloc] initWithName:DISPLAYED_NAME xmlns:XMLNS_CHAT_MARKERS];
    [readDisplayedMarker addAttributeWithName:@"id" stringValue:elementID];

    [self addChild:readDisplayedMarker];
}

- (void)addAcknowledgedChatMarkerWithID:(NSString *)elementID
{
    NSXMLElement *acknowledgedChatMarker = [[NSXMLElement alloc] initWithName:ACKNOWLEDGED_NAME xmlns:XMLNS_CHAT_MARKERS];
    [acknowledgedChatMarker addAttributeWithName:@"id" stringValue:elementID];
    
    [self addChild:acknowledgedChatMarker];
}

- (XMPPMessage *)generateReceivedChatMarker
{
    return [self generateReceivedChatMarkerIncludingThread:NO];
}

- (XMPPMessage *)generateDisplayedChatMarker
{
    return [self generateDisplayedChatMarkerIncludingThread:NO];
}

- (XMPPMessage *)generateAcknowledgedChatMarker
{
    return [self generateAcknowledgedChatMarkerIncludingThread:NO];
}

- (XMPPMessage *)generateReceivedChatMarkerIncludingThread:(BOOL)includingThread
{
    XMPPMessage *message = [XMPPMessage message];
    [message addAttributeWithName:@"to" stringValue:[self fromStr]];
    
    if(includingThread && [self thread])
    {
        [message addThread:[self thread]];
    }
    
    [message addReceivedChatMarkerWithID:[self elementID]];
    
    return message;
}
- (XMPPMessage *)generateDisplayedChatMarkerIncludingThread:(BOOL)includingThread
{
    XMPPMessage *message = [XMPPMessage message];
    [message addAttributeWithName:@"to" stringValue:[self fromStr]];
    
    if(includingThread && [self thread])
    {
        [message addThread:[self thread]];
    }
    
    [message addDisplayedChatMarkerWithID:[self elementID]];
    return message;
}
- (XMPPMessage *)generateAcknowledgedChatMarkerIncludingThread:(BOOL)includingThread
{
    XMPPMessage *message = [XMPPMessage message];
    [message addAttributeWithName:@"to" stringValue:[self fromStr]];
    
    if(includingThread && [self thread])
    {
        [message addThread:[self thread]];
    }
    
    [message addAcknowledgedChatMarkerWithID:[self elementID]];
    return message;
}
@end
