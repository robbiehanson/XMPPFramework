#import "XMPPParser.h"
#import "DDXMLPrivate.h"

/**
 * How does this class work?
 * 
 * The libxml DOM interface is written on top of their SAX interface.
 * So to build a DOM tree from a document, libxml creates a SAX parser,
 * and then proceeds to iteratively create the tree from within the SAX callback functions.
 * 
 * What we do is monitor the SAX callbacks (AKA the DOM tree building callbacks)
 * to keep tabs on when elements are coming in.
 * When we see a complete element, then we simply extract it from the tree, and pass it to the delegate.
**/

@implementation XMPPParser

/**
 * Our override for the SAX start element callback.
 * We use this method to keep tabs on where we are within the document.
 * Ultimately, we want to know when we've finished reading a full xmpp node so we can pass it to the delegate.
**/
static void	onStartElementNs(void *ctx, const xmlChar  *localname,
                                        const xmlChar  *prefix,
                                        const xmlChar  *URI,
                                                  int   nb_namespaces,
                                        const xmlChar **namespaces,
                                                  int   nb_attributes,
                                                  int   nb_defaulted,
                                        const xmlChar **attributes)
{
	xmlParserCtxt *ctxt = (xmlParserCtxt *)ctx;
	xmlSAXHandler *hdlr = ctxt->sax;
	
	XMPPParser *parser = (XMPPParser *)hdlr->_private;
	
	parser->depth++;
	parser->domStartElementNs(ctxt, localname, prefix, URI, nb_namespaces, namespaces,
	                          nb_attributes, nb_defaulted, attributes);
	
	if(!(parser->hasReportedRoot) && (parser->depth == 1))
	{
		// We've received the full root - report it to the delegate
		
		if(ctxt->myDoc)
		{
			xmlNodePtr root = xmlDocGetRootElement(ctxt->myDoc);
			if(root)
			{
				if([parser->delegate respondsToSelector:@selector(xmppParser:didReadRoot:)])
				{
					// We first copy the root node.
					// We do this to allow the delegate to retain and make changes to the reported root
					// without affecting the underlying xmpp parser.
					
					// xmlCopyNode(const xmlNodePtr node, int extended)
					// 
					// node:
					//   the node to copy
					// extended:
					//   if 1 do a recursive copy (properties, namespaces and children when applicable)
					//   if 2 copy properties and namespaces (when applicable)
					
					xmlNodePtr rootCopy = xmlCopyNode(root, 2);
					DDXMLElement *rootCopyWrapper = [DDXMLElement nodeWithPrimitive:(xmlKindPtr)rootCopy];
					
					[parser->delegate xmppParser:parser didReadRoot:rootCopyWrapper];
					
					// Note: DDXMLElement will properly free the rootCopy when it's deallocated.
				}
				
				parser->hasReportedRoot = YES;
			}
		}
	}
}

static void onEndElementNs(void *ctx, const xmlChar *localname,
                                      const xmlChar *prefix,
                                      const xmlChar *URI)
{
	xmlParserCtxt *ctxt = (xmlParserCtxt *)ctx;
	xmlSAXHandler *hdlr = ctxt->sax;
	
	XMPPParser *parser = (XMPPParser *)hdlr->_private;
	
	parser->domEndElementNs(ctx, localname, prefix, URI);
	parser->depth--;
	
	if(parser->depth == 1)
	{
		// End of full xmpp element.
		// That is, a child of the root element.
		// Extract the child, and pass it to the delegate.
		
		xmlDocPtr doc = ctxt->myDoc;
		xmlNodePtr root = xmlDocGetRootElement(doc);
		
		xmlNodePtr child = root->children;
		while(child != NULL)
		{
			if(child->type == XML_ELEMENT_NODE)
			{
				[DDXMLNode detachChild:child fromNode:root];
				DDXMLElement *childWrapper = [DDXMLElement nodeWithPrimitive:(xmlKindPtr)child];
				
				// Note: We want to detach the child from the root even if the delegate method isn't setup.
				// This prevents the doc from growing infinitely large.
				
				if([parser->delegate respondsToSelector:@selector(xmppParser:didReadElement:)])
				{
					[parser->delegate xmppParser:parser didReadElement:childWrapper];
				}
				
				// Note: DDXMLElement will properly free the child when it's deallocated.
				
				break;
			}
			
			child = child->next;
		}
	}
	else if(parser->depth == 0)
	{
		// End of the root element
		
		if([parser->delegate respondsToSelector:@selector(xmppParserDidEnd:)])
		{
			[parser->delegate xmppParserDidEnd:parser];
		}
	}
}

- (id)initWithDelegate:(id)aDelegate
{
	if((self = [super init]))
	{
		delegate = aDelegate;
		
		hasReportedRoot = NO;
		depth  = 0;
		
		// Create SAX handler
		xmlSAXHandler saxHandler;
		memset(&saxHandler, 0, sizeof(xmlSAXHandler));
		
		// Initialize handler to default values,
		// which will point each SAX callback function to the DOM tree-building functions.
		xmlSAXVersion(&saxHandler, 2);
		
		// Store references to original functions (before we override them)
		domStartElementNs = saxHandler.startElementNs;
		domEndElementNs   = saxHandler.endElementNs;
		
		// Tell libxml not to keep ignorable whitespace (such as node indentation, formatting, etc).
		// NSXML ignores such whitespace.
		// This also has the added benefit of taking up less RAM when parsing formatted XML documents.
		saxHandler.ignorableWhitespace = xmlSAX2IgnorableWhitespace;
		
		// Setup overrides, and store reference to ourself for use in the C-style callback functions
		saxHandler.startElementNs = onStartElementNs;
		saxHandler.endElementNs   = onEndElementNs;
		saxHandler._private       = self;
		
		// Create the push parser context
		parserCtxt = xmlCreatePushParserCtxt(&saxHandler, NULL, NULL, 0, NULL);
		
		// Note: This method copies the saxHandler, so we don't have to keep it around.
		
		// Note: The parserCtxt also has a useData variable, but it is used by the DOM building functions.
		// If we put a value there, it actually causes a crash!
		// So instead we add a reference to ourself in the saxHandler.
	}
	return self;
}

- (void)dealloc
{
	if(parserCtxt)
	{
		// The xmlFreeParserCtxt method will not free the created document in parserCtxt->myDoc.
		// It will also not free the application data in sax->_private either (obviously).
		
		if(parserCtxt->myDoc)
		{
			// Free the created xmlDoc
			xmlFreeDoc(parserCtxt->myDoc);
		}
		
		xmlFreeParserCtxt(parserCtxt);
	}
	
	[super dealloc];
}

- (id)delegate {
	return delegate;
}
- (void)setDelegate:(id)aDelegate {
	delegate = aDelegate;
}

- (void)parseData:(NSData *)data
{
	// The xmlParseChunk method below will cause the delegate methods to be invoked before this method returns.
	// If the delegate subsequently attempts to release us in one of those methods, and our dealloc method
	// gets invoked, then the parserCtxt will be freed in the middle of the xmlParseChunk method.
	// This often has the effect of crashing the application.
	// To get around this problem we simply retain/release within the method.
	[self retain];
	
	int result = xmlParseChunk(parserCtxt, (const char *)[data bytes], [data length], 0);
	
	if(result != 0)
	{
		if([delegate respondsToSelector:@selector(xmppParser:didFail:)])
		{
			NSError *error;
			
			xmlError *xmlErr = xmlCtxtGetLastError(parserCtxt);
			
			if(xmlErr->message)
			{
				NSString *errMsg = [NSString stringWithFormat:@"%s", xmlErr->message];
				NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
				
				error = [NSError errorWithDomain:@"libxmlErrorDomain" code:xmlErr->code userInfo:info];
			}
			else
			{
				error = [NSError errorWithDomain:@"libxmlErrorDomain" code:xmlErr->code userInfo:nil];
			}
			
			[delegate xmppParser:self didFail:error];
		}
	}
	
	[self release];
}

@end
