#import <Foundation/Foundation.h>
#import "XMPPElement.h"

/**
 * The XMPPMessage class represents a <message> element.
 * It extends XMPPElement, which in turn extends NSXMLElement.
 * All <message> elements that go in and out of the
 * xmpp stream will automatically be converted to XMPPMessage objects.
 * 
 * This class exists to provide developers an easy way to add functionality to message processing.
 * Simply add your own category to XMPPMessage to extend it with your own custom methods.
**/

@interface XMPPMessage : XMPPElement

// Converts an NSXMLElement to an XMPPMessage element in place (no memory allocations or copying)
+ (XMPPMessage *)messageFromElement:(NSXMLElement *)element;

+ (XMPPMessage *)message;
+ (XMPPMessage *)messageWithType:(NSString *)type;
+ (XMPPMessage *)messageWithType:(NSString *)type to:(XMPPJID *)to;
+ (XMPPMessage *)messageWithType:(NSString *)type to:(XMPPJID *)jid elementID:(NSString *)eid;
+ (XMPPMessage *)messageWithType:(NSString *)type to:(XMPPJID *)jid elementID:(NSString *)eid child:(NSXMLElement *)childElement;
+ (XMPPMessage *)messageWithType:(NSString *)type elementID:(NSString *)eid;
+ (XMPPMessage *)messageWithType:(NSString *)type elementID:(NSString *)eid child:(NSXMLElement *)childElement;
+ (XMPPMessage *)messageWithType:(NSString *)type child:(NSXMLElement *)childElement;

- (id)init;
- (id)initWithType:(NSString *)type;
- (id)initWithType:(NSString *)type to:(XMPPJID *)to;
- (id)initWithType:(NSString *)type to:(XMPPJID *)jid elementID:(NSString *)eid;
- (id)initWithType:(NSString *)type to:(XMPPJID *)jid elementID:(NSString *)eid child:(NSXMLElement *)childElement;
- (id)initWithType:(NSString *)type elementID:(NSString *)eid;
- (id)initWithType:(NSString *)type elementID:(NSString *)eid child:(NSXMLElement *)childElement;
- (id)initWithType:(NSString *)type child:(NSXMLElement *)childElement;

- (NSString *)type;
- (NSString *)subject;
- (NSString *)body;
- (NSString *)bodyForLanguage:(NSString *)language;
- (NSString *)thread;

- (void)addSubject:(NSString *)subject;
- (void)addBody:(NSString *)body;
- (void)addBody:(NSString *)body withLanguage:(NSString *)language;
- (void)addThread:(NSString *)thread;

- (BOOL)isChatMessage;
- (BOOL)isChatMessageWithBody;
- (BOOL)isErrorMessage;
- (BOOL)isMessageWithBody;

- (NSError *)errorMessage;

@end
