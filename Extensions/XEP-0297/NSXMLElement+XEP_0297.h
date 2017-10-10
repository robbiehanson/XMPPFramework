#import <Foundation/Foundation.h>

@import KissXML;

@class XMPPIQ;
@class XMPPMessage;
@class XMPPPresence;

NS_ASSUME_NONNULL_BEGIN
@interface NSXMLElement (XEP_0297)

#pragma mark Forwarded Stanza 

@property (nonatomic, readonly, nullable) NSXMLElement *forwardedStanza;

@property (nonatomic, readonly) BOOL hasForwardedStanza;

@property (nonatomic, readonly) BOOL isForwardedStanza;

#pragma mark Delayed Delivery Date

@property (nonatomic, readonly, nullable) NSDate *forwardedStanzaDelayedDeliveryDate;

#pragma mark XMPPElement

@property (nonatomic, readonly, nullable) XMPPIQ *forwardedIQ;

@property (nonatomic, readonly) BOOL hasForwardedIQ;

@property (nonatomic, readonly, nullable) XMPPMessage *forwardedMessage;

@property (nonatomic, readonly) BOOL hasForwardedMessage;

@property (nonatomic, readonly, nullable) XMPPPresence *forwardedPresence;

@property (nonatomic, readonly) BOOL hasForwardedPresence;

@end
NS_ASSUME_NONNULL_END
