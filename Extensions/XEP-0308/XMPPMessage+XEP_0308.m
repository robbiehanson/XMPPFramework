#import "XMPPMessage+XEP_0308.h"
#import "NSXMLElement+XMPP.h"


#define NAME_XMPP_MESSAGE_CORRECT @"replace"
#define XMLNS_XMPP_MESSAGE_CORRECT @"urn:xmpp:message-correct:0"

@implementation XMPPMessage (XEP_0308)

- (BOOL)isMessageCorrection
{    
    if([[self correctedMessageID] length])
    {
        return YES;
    }else{
        return NO;
    }
}

- (NSString *)correctedMessageID
{
    return [[self elementForName:NAME_XMPP_MESSAGE_CORRECT xmlns:XMLNS_XMPP_MESSAGE_CORRECT] attributeStringValueForName:@"id"];
}

- (void)addMessageCorrectionWithID:(NSString *)messageCorrectionID
{
    NSXMLElement *replace = [NSXMLElement elementWithName:NAME_XMPP_MESSAGE_CORRECT stringValue:XMLNS_XMPP_MESSAGE_CORRECT];
    [replace addAttributeWithName:@"id" stringValue:messageCorrectionID];
    [self addChild:replace];
}

@end
