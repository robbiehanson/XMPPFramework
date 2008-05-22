#import <Cocoa/Cocoa.h>
#import "XMPPElement.h"


@interface XMPPIQ : XMPPElement

+ (XMPPIQ *)iqFromElement:(NSXMLElement *)element;

+ (BOOL)isRosterItem:(NSXMLElement *)item;

- (BOOL)isRosterQuery;

@end
