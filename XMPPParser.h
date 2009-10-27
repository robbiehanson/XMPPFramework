#import <Foundation/Foundation.h>
#import <libxml2/libxml/parser.h>

@class DDXMLElement;

/**
 * This class was designed specifically for the iPhone
 * and ties in with libxml and the KissXML framework (which is the NSXML replacement for the iPhone SDK).
 * 
 * The result is a huge performance boost, especially when parsing large xmpp fragments.
 * For example, when parsing large rosters or big IQ responses.
 * 
 * You should NOT use this class on non-iPhone platforms.
 * Another separate XMPPParser is planned for Mac OS X platforms.
**/

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

- (void)xmppParser:(XMPPParser *)sender didReadRoot:(DDXMLElement *)root;

- (void)xmppParser:(XMPPParser *)sender didReadElement:(DDXMLElement *)element;

- (void)xmppParserDidEnd:(XMPPParser *)sender;

- (void)xmppParser:(XMPPParser *)sender didFail:(NSError *)error;

@end
