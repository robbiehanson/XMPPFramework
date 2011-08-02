#import <Foundation/Foundation.h>
#import "XMPPElement.h"

/**
 * The XMPPPresence class represents a <presence> element.
 * It extends XMPPElement, which in turn extends NSXMLElement.
 * All <presence> elements that go in and out of the
 * xmpp stream will automatically be converted to XMPPPresence objects.
 * 
 * This class exists to provide developers an easy way to add functionality to presence processing.
 * Simply add your own category to XMPPPresence to extend it with your own custom methods.
**/

@interface XMPPPresence : XMPPElement

// Converts an NSXMLElement to an XMPPPresence element in place (no memory allocations or copying)
+ (XMPPPresence *)presenceFromElement:(NSXMLElement *)element;

+ (XMPPPresence *)presence;
+ (XMPPPresence *)presenceWithType:(NSString *)type;
+ (XMPPPresence *)presenceWithType:(NSString *)type to:(XMPPJID *)to;

- (id)init;
- (id)initWithType:(NSString *)type;
- (id)initWithType:(NSString *)type to:(XMPPJID *)to;

- (NSString *)type;

- (NSString *)show;
- (NSString *)status;

- (int)priority;

- (int)intShow;

- (BOOL)isErrorPresence;

@end
