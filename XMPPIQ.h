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

@interface XMPPIQ : XMPPElement

// Converts an NSXMLElement to an XMPPIQ element in place (no memory allocations or copying)
+ (XMPPIQ *)iqFromElement:(NSXMLElement *)element;

- (NSString *)type;

- (NSXMLElement *)queryElement;

- (BOOL)isGetIQ;
- (BOOL)isSetIQ;
- (BOOL)isResultIQ;
- (BOOL)isErrorIQ;

- (BOOL)requiresResponse;

@end
