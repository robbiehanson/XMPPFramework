#import "XMPPFeature.h"

@interface XMPPFeature ()
{
    
}
@property (strong, readwrite) XMPPStream * xmppStream;
@end

@implementation XMPPFeature
- (void)activate:(XMPPStream *)xmppStream
{
    self.xmppStream = xmppStream;
    [self.xmppStream addFeature:self];
}

- (void)deactivate
{
    [self.xmppStream removeFeature:self];
}

- (BOOL)handleFeatures:(NSXMLElement *)features
{
    return NO;
}

- (BOOL)handleElement:(NSXMLElement *)element
{
    return NO;
}

@end
