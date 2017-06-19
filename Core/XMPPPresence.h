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
NS_ASSUME_NONNULL_BEGIN
@interface XMPPPresence : XMPPElement

// Converts an NSXMLElement to an XMPPPresence element in place (no memory allocations or copying)
+ (XMPPPresence *)presenceFromElement:(NSXMLElement *)element;

+ (XMPPPresence *)presence;
+ (XMPPPresence *)presenceWithType:(nullable NSString *)type;
+ (XMPPPresence *)presenceWithType:(nullable NSString *)type to:(nullable XMPPJID *)to;

- (instancetype)init;
- (instancetype)initWithType:(nullable NSString *)type;
- (instancetype)initWithType:(nullable NSString *)type to:(nullable XMPPJID *)to;

@property (nonatomic, readonly, nullable) NSString *type;

@property (nonatomic, readonly, nullable) NSString *show;
@property (nonatomic, readonly, nullable) NSString *status;

- (int)priority;

- (int)intShow;

- (BOOL)isErrorPresence;

@end
NS_ASSUME_NONNULL_END
