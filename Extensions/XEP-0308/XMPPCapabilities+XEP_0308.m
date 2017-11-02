#import "XMPPCapabilities+XEP_0308.h"

static NSString * const XMPPLastMessageCorrectionCapabilitiesFeature = @"urn:xmpp:message-correct:0";

@implementation XMPPCapabilities (XEP_0308)

- (BOOL)isLastMessageCorrectionCapabilityConfirmedForJID:(XMPPJID *)jid
{
    if (![self.xmppCapabilitiesStorage areCapabilitiesKnownForJID:jid xmppStream:self.xmppStream]) {
        return NO;
    }
    
    NSXMLElement *capabilities = [self.xmppCapabilitiesStorage capabilitiesForJID:jid xmppStream:self.xmppStream];
    for (NSXMLElement *feature in [capabilities children]) {
        if ([[feature name] isEqualToString:@"feature"]
            && [[feature attributeStringValueForName:@"var"] isEqualToString:XMPPLastMessageCorrectionCapabilitiesFeature]) {
            return YES;
        }
    }
    
    return NO;
}

@end
