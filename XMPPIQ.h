#import <Cocoa/Cocoa.h>


@interface XMPPIQ : NSXMLElement

+ (XMPPIQ *)iqFromElement:(NSXMLElement *)element;

+ (BOOL)isRosterItem:(NSXMLElement *)item;

- (BOOL)isRosterQuery;

@end
