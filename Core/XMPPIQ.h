#import <Foundation/Foundation.h>
#import "XMPPElement.h"

/**
 * The XMPPIQ class represents an <iq> element.
 * It extends XMPPElement, which in turn extends NSXMLElement.
 * All <iq> elements that go in and out of the
 * xmpp stream will automatically be converted to XMPPIQ objects.
 * 
 * This class exists to provide developers an easy way to add functionality to IQ processing.
 * Simply add your own category to XMPPIQ to extend it with your own custom methods.
**/

NS_ASSUME_NONNULL_BEGIN
@interface XMPPIQ : XMPPElement

/**
 * Converts an NSXMLElement to an XMPPIQ element in place (no memory allocations or copying)
**/
+ (XMPPIQ *)iqFromElement:(NSXMLElement *)element;

/**
 * Creates and returns a new autoreleased XMPPIQ element.
 * If the type or elementID parameters are nil, those attributes will not be added.
**/
+ (XMPPIQ *)iq;
+ (XMPPIQ *)iqWithType:(nullable NSString *)type;
+ (XMPPIQ *)iqWithType:(nullable NSString *)type to:(nullable XMPPJID *)jid;
+ (XMPPIQ *)iqWithType:(nullable NSString *)type to:(nullable XMPPJID *)jid elementID:(nullable NSString *)eid;
+ (XMPPIQ *)iqWithType:(nullable NSString *)type to:(nullable XMPPJID *)jid elementID:(nullable NSString *)eid child:(nullable NSXMLElement *)childElement;
+ (XMPPIQ *)iqWithType:(nullable NSString *)type elementID:(nullable NSString *)eid;
+ (XMPPIQ *)iqWithType:(nullable NSString *)type elementID:(nullable NSString *)eid child:(nullable NSXMLElement *)childElement;
+ (XMPPIQ *)iqWithType:(nullable NSString *)type child:(nullable NSXMLElement *)childElement;

/**
 * Creates and returns a new XMPPIQ element.
 * If the type or elementID parameters are nil, those attributes will not be added.
**/
- (instancetype)init;
- (instancetype)initWithType:(nullable NSString *)type;
- (instancetype)initWithType:(nullable NSString *)type to:(nullable XMPPJID *)jid;
- (instancetype)initWithType:(nullable NSString *)type to:(nullable XMPPJID *)jid elementID:(nullable NSString *)eid;
- (instancetype)initWithType:(nullable NSString *)type to:(nullable XMPPJID *)jid elementID:(nullable NSString *)eid child:(nullable NSXMLElement *)childElement;
- (instancetype)initWithType:(nullable NSString *)type elementID:(nullable NSString *)eid;
- (instancetype)initWithType:(nullable NSString *)type elementID:(nullable NSString *)eid child:(nullable NSXMLElement *)childElement;
- (instancetype)initWithType:(nullable NSString *)type child:(nullable NSXMLElement *)childElement;

/**
 * Returns the type attribute of the IQ.
 * According to the XMPP protocol, the type should be one of 'get', 'set', 'result' or 'error'.
 * 
 * This method converts the attribute to lowercase so
 * case-sensitive string comparisons are safe (regardless of server treatment).
**/
@property (nonatomic, readonly, nullable) NSString *type;

/**
 * Convenience methods for determining the IQ type.
**/
@property (nonatomic, readonly) BOOL isGetIQ;
@property (nonatomic, readonly) BOOL isSetIQ;
@property (nonatomic, readonly) BOOL isResultIQ;
@property (nonatomic, readonly) BOOL isErrorIQ;

/**
 * Convenience method for determining if the IQ is of type 'get' or 'set'.
**/
@property (nonatomic, readonly) BOOL requiresResponse;

/**
 * The XMPP RFC has various rules for the number of child elements an IQ is allowed to have:
 * 
 * - An IQ stanza of type "get" or "set" MUST contain one and only one child element.
 * - An IQ stanza of type "result" MUST include zero or one child elements.
 * - An IQ stanza of type "error" SHOULD include the child element contained in the
 *   associated "get" or "set" and MUST include an <error/> child.
 * 
 * The childElement returns the single non-error element, if one exists, or nil.
 * The childErrorElement returns the error element, if one exists, or nil.
**/
@property (nonatomic, readonly, nullable) NSXMLElement *childElement;
@property (nonatomic, readonly, nullable) NSXMLElement *childErrorElement;

@end
NS_ASSUME_NONNULL_END
