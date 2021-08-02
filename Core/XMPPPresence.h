#import <Foundation/Foundation.h>
#import "XMPPElement.h"

// https://xmpp.org/rfcs/rfc6121.html#presence-syntax-children-show
typedef NS_ENUM(NSInteger, XMPPPresenceShow) {
    /** Do not disturb */
    XMPPPresenceShowDND,
    /** Extended Away */
    XMPPPresenceShowXA,
    /** Away */
    XMPPPresenceShowAway,
    /** Unrecognized value, or not present */
    XMPPPresenceShowOther,
    /** Active and available for chatting */
    XMPPPresenceShowChat
};

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

@property (nonatomic, readonly) NSInteger priority;

/** This supercedes the previous intShow method */
@property (nonatomic, readonly) XMPPPresenceShow showValue;

/** @warn Use showValue instead. This property will be removed in a future release. */
@property (nonatomic, readonly) NSInteger intShow DEPRECATED_MSG_ATTRIBUTE("Use showValue instead. This property will be removed in a future release.");

@property (nonatomic, readonly) BOOL isErrorPresence;

@end
NS_ASSUME_NONNULL_END
