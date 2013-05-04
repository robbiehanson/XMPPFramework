#import <Foundation/Foundation.h>
#import "XMPPJID.h"

#if TARGET_OS_IPHONE
  #import "DDXML.h"
#endif


/**
 * The XMPPElement provides the base class for XMPPIQ, XMPPMessage & XMPPPresence.
 * 
 * This class extends NSXMLElement.
 * The NSXML classes (NSXMLElement & NSXMLNode) provide a full-featured library for working with XML elements.
 * 
 * On the iPhone, the KissXML library provides a drop-in replacement for Apple's NSXML classes.
**/

@interface XMPPElement : NSXMLElement <NSCoding, NSCopying>

#pragma mark Common Jabber Methods

- (NSString *)elementID;

- (XMPPJID *)to;
- (XMPPJID *)from;

- (NSString *)toStr;
- (NSString *)fromStr;

#pragma mark To and From Methods

- (BOOL)isTo:(XMPPJID *)to;
- (BOOL)isTo:(XMPPJID *)to options:(XMPPJIDCompareOptions)mask;

- (BOOL)isFrom:(XMPPJID *)from;
- (BOOL)isFrom:(XMPPJID *)from options:(XMPPJIDCompareOptions)mask;

- (BOOL)isToOrFrom:(XMPPJID *)toOrFrom;
- (BOOL)isToOrFrom:(XMPPJID *)toOrFrom options:(XMPPJIDCompareOptions)mask;

- (BOOL)isTo:(XMPPJID *)to from:(XMPPJID *)from;
- (BOOL)isTo:(XMPPJID *)to from:(XMPPJID *)from options:(XMPPJIDCompareOptions)mask;

@end
