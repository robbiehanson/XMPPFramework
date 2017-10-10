#import <Foundation/Foundation.h>

@import KissXML;
NS_ASSUME_NONNULL_BEGIN
@protocol XMPPParserDelegate;
@interface XMPPParser : NSObject

- (instancetype)initWithDelegate:(nullable id<XMPPParserDelegate>)delegate delegateQueue:(nullable dispatch_queue_t)dq;
- (instancetype)initWithDelegate:(nullable id<XMPPParserDelegate>)delegate delegateQueue:(nullable dispatch_queue_t)dq parserQueue:(nullable dispatch_queue_t)pq;

- (void)setDelegate:(nullable id<XMPPParserDelegate>)delegate delegateQueue:(nullable dispatch_queue_t)delegateQueue;

/**
 * Asynchronously parses the given data.
 * The delegate methods will be dispatch_async'd as events occur.
**/
- (void)parseData:(NSData *)data;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol XMPPParserDelegate
@optional

- (void)xmppParser:(XMPPParser *)sender didReadRoot:(NSXMLElement *)root;

- (void)xmppParser:(XMPPParser *)sender didReadElement:(NSXMLElement *)element;

- (void)xmppParserDidEnd:(XMPPParser *)sender;

- (void)xmppParser:(XMPPParser *)sender didFail:(NSError *)error;

- (void)xmppParserDidParseData:(XMPPParser *)sender;

@end
NS_ASSUME_NONNULL_END
