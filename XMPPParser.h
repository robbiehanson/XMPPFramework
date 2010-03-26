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
}

- (id)initWithDelegate:(id)delegate;

- (id)delegate;
- (void)setDelegate:(id)delegate;

/**
 * Synchronously parses the given data.
 * This means the delegate methods will get called before this method returns.
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

@end
