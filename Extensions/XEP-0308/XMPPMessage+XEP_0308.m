#import "XMPPMessage+XEP_0308.h"
#import "NSXMLElement+XMPP.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

#define NAME_XMPP_MESSAGE_CORRECT @"replace"
#define XMLNS_XMPP_MESSAGE_CORRECT @"urn:xmpp:message-correct:0"

@implementation XMPPMessage (XEP_0308)

- (BOOL)isMessageCorrection
{    
    if([[self correctedMessageID] length])
    {
        return YES;
    }
    else
    {
        return NO;
    }
}

- (NSString *)correctedMessageID
{
    return [[self elementForName:NAME_XMPP_MESSAGE_CORRECT xmlns:XMLNS_XMPP_MESSAGE_CORRECT] attributeStringValueForName:@"id"];
}

- (void)addMessageCorrectionWithID:(NSString *)messageCorrectionID
{
    NSXMLElement *replace = [NSXMLElement elementWithName:NAME_XMPP_MESSAGE_CORRECT xmlns:XMLNS_XMPP_MESSAGE_CORRECT];
    [replace addAttributeWithName:@"id" stringValue:messageCorrectionID];
    [self addChild:replace];
}

- (XMPPMessage *)generateCorrectionMessageWithID:(NSString *)elementID
{
    XMPPMessage *correctionMessage = nil;

    if([[self elementID] length] && ![self isMessageCorrection])
    {
        correctionMessage = [self copy];

        [correctionMessage removeAttributeForName:@"id"];

        if([elementID length])
        {
            [correctionMessage addAttributeWithName:@"id" stringValue:elementID];
        }

        [correctionMessage addMessageCorrectionWithID:[self elementID]];
    }

    return correctionMessage;
}

- (XMPPMessage *)generateCorrectionMessageWithID:(NSString *)elementID body:(NSString *)body
{
    XMPPMessage *correctionMessage = nil;

    if([[self elementID] length] && ![self isMessageCorrection])
    {
        correctionMessage = [self copy];

        [correctionMessage removeAttributeForName:@"id"];

        if([elementID length])
        {
            [correctionMessage addAttributeWithName:@"id" stringValue:elementID];
        }

        NSXMLElement *bodyElement = [correctionMessage elementForName:@"body"];

        if(bodyElement)
        {
            [correctionMessage removeChildAtIndex:[[correctionMessage children] indexOfObject:bodyElement]];
        }

        [correctionMessage addBody:body];

        [correctionMessage addMessageCorrectionWithID:[self elementID]];
    }

    return correctionMessage;
}

@end
