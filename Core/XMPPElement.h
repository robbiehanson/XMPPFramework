#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE
  #import "DDXML.h"
#endif

@class XMPPJID;

/**
 * The XMPPElement provides the base class for XMPPIQ, XMPPMessage & XMPPPresence.
 * 
 * This class extends NSXMLElement.
 * The NSXML classes (NSXMLElement & NSXMLNode) provide a full-featured library for working with XML elements.
 * 
 * On the iPhone, the KissXML library provides a drop-in replacement for Apple's NSXML classes.
**/

@interface XMPPElement : NSXMLElement <NSCoding, NSCopying>

- (NSString *)elementID;

- (XMPPJID *)to;
- (XMPPJID *)from;

- (NSString *)toStr;
- (NSString *)fromStr;

@end
