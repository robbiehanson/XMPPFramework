#import <Foundation/Foundation.h>
#import <libxml2/libxml/parser.h>

#if TARGET_OS_IPHONE
  #import "DDXML.h"
#endif


@interface XMPPParser : NSObject
{
	id delegate;
	
	BOOL hasReportedRoot;
	unsigned depth;
	
	xmlParserCtxt *parserCtxt;
	
	BOOL stopped;
	
	NSThread *streamThread;
	NSThread *parsingThread;
}

- (id)initWithDelegate:(id)delegate;

/**
 * Asynchronously parses the given data.
 * The delegate methods will be called as elements are fully read and parsed.
**/
- (void)parseData:(NSData *)data;

/**
 * You must call this method before releasing the parser.
 * This will stop any asynchronous parsing, and ensure that no further delegate methods are invoked.
 * 
 * Failure to call this method will also leak the parser object.
**/
- (void)stop;

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

- (void)xmppParser:(XMPPParser *)sender didParseDataOfLength:(NSUInteger)length;

@end
