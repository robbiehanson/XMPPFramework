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

enum {
	XMPPPresenceShowNone = 0,
	XMPPPresenceShowBusy = 1,
	XMPPPresenceShowExtendedAway = 2,
	XMPPPresenceShowAway = 3,
	XMPPPresenceShowChat = 4
};
typedef NSUInteger XMPPPresenceShowType;

@interface XMPPPresence : XMPPElement

// Converts an NSXMLElement to an XMPPPresence element in place (no memory allocations or copying)
+ (XMPPPresence *)presenceFromElement:(NSXMLElement *)element;

+ (XMPPPresence *)presence;
+ (XMPPPresence *)presenceWithType:(NSString *)type;
+ (XMPPPresence *)presenceWithType:(NSString *)type to:(XMPPJID *)to;

- (id)init;
- (id)initWithType:(NSString *)type;
- (id)initWithType:(NSString *)type to:(XMPPJID *)to;

@property (nonatomic, retain) NSString *type;
@property (nonatomic, retain) NSString *show;
@property (nonatomic, assign) XMPPPresenceShowType showType;
@property (nonatomic, retain) NSString *status;
@property (nonatomic, assign) NSInteger priority;
@property (nonatomic, assign) BOOL available;
@property (nonatomic, strong) XMPPJID *from;
@property (nonatomic, strong) XMPPJID *to;

- (BOOL)isErrorPresence;

// This is for backward compatibility.
// New implementations should use showType instead
- (int)intShow;
@end
