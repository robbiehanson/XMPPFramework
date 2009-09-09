#import "XMPPParser.h"
#import "DDXMLPrivate.h"

#define CHECK_FOR_NULL(value) do { if(value == NULL) { xmlAbortDueToMemoryShortage(ctxt); return; } } while(false)


@implementation XMPPParser

/**
 * This method is called at the end of the xmlStartElement method.
 * This allows us to inspect the parser and xml tree, and determine if we need to invoke any delegate methods.
**/
static void postStartElement(xmlParserCtxt *ctxt)
{
	XMPPParser *parser = (XMPPParser *)ctxt->_private;
	parser->depth++;
	
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

/**
 * This method is called at the end of the xmlEndElement method.
 * This allows us to inspect the parser and xml tree, and determine if we need to invoke any delegate methods.
**/
static void postEndElement(xmlParserCtxt *ctxt)
{
	XMPPParser *parser = (XMPPParser *)ctxt->_private;
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
				DDXMLElement *childWrapper = [DDXMLElement nodeWithPrimitive:(xmlKindPtr)child];
				[childWrapper detach];
				
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

/**
 * We're screwed...
**/
static void xmlAbortDueToMemoryShortage(xmlParserCtxt *ctxt)
{
	XMPPParser *parser = (XMPPParser *)ctxt->_private;
	
	xmlStopParser(ctxt);
	
	if([parser->delegate respondsToSelector:@selector(xmppParser:didFail:)])
	{
		NSString *errMsg = @"Unable to allocate memory in xmpp parser";
		NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
		
		NSError *error = [NSError errorWithDomain:@"libxmlErrorDomain" code:1001 userInfo:info];
		
		[parser->delegate xmppParser:parser didFail:error];
	}
}

/**
 * SAX parser C-style callback.
 * Invoked when a new node element is started.
**/
static void	xmlStartElement(void *ctx, const xmlChar  *nodeName,
                                       const xmlChar  *nodePrefix,
                                       const xmlChar  *nodeUri,
                                                 int   nb_namespaces,
                                       const xmlChar **namespaces,
                                                 int   nb_attributes,
                                                 int   nb_defaulted,
                                       const xmlChar **attributes)
{
	int i, j;
	xmlNsPtr lastAddedNs;
	
	xmlParserCtxt *ctxt = (xmlParserCtxt *)ctx;
	
	// We store the parent node in the context's node pointer.
	// We keep this updated by "pushing" the node in the startElement method,
	// and "popping" the node in the endElement method.
	xmlNodePtr parent = ctxt->node;
	
	// Create the node
	xmlNodePtr newNode = xmlNewDocNode(ctxt->myDoc, NULL, nodeName, NULL);
	CHECK_FOR_NULL(newNode);
	
	// Add the node to the tree
	if(parent == NULL)
	{
		// Root node
		xmlAddChild((xmlNodePtr)ctxt->myDoc, newNode);
	}
	else
	{
		xmlAddChild(parent, newNode);
	}
	
	// Process the namespaces
	for(i = 0, j = 0; j < nb_namespaces; j++)
	{
		// Extract namespace prefix and uri
		const xmlChar *nsPrefix = namespaces[i++];
		const xmlChar *nsUri    = namespaces[i++];
		
		// Create the namespace
		xmlNsPtr newNs = xmlNewNs(NULL, nsUri, nsPrefix);
		CHECK_FOR_NULL(newNs);
		
		// Add namespace to node.
		// Each node has a linked list of nodes (in the nsDef variable).
		// The linked list is forward only.
		// In other words, each ns has a next, but not a prev pointer.
		
		if (newNode->nsDef == NULL)
		{
			newNode->nsDef = lastAddedNs = newNs;
		}
		else
		{
			lastAddedNs->next = newNs;
			lastAddedNs = newNs;
		}
		
		if ((nodeUri != NULL) && (nodePrefix == nsPrefix))
		{
			// This is the namespace for the node.
			// Example 1: the node was <stream:stream xmlns:stream="url"> and newNs is the stream:url namespace.
			// Example 2: the node was <starttls xmlns="url"> and newNs is the null:url namespace.
			newNode->ns = newNs;
		}
	}
	
	// Search for the node's namespace if it wasn't already found
	if ((nodeUri != NULL) && (newNode->ns == NULL))
	{
		// xmlSearchNs(xmlDocPtr doc, xmlNodePtr node, const xmlChar *nameSpace)
		// 
		// Search a Ns registered under a given name space for a document.
		// Recurse on the parents until it finds the defined namespace or return NULL otherwise.
		// The nameSpace parameter can be NULL, this is a search for the default namespace.
		
		newNode->ns = xmlSearchNs(ctxt->myDoc, parent, nodePrefix);
		
		if (newNode->ns == NULL)
		{
			// We use href==NULL in the case of an element creation where the namespace was not defined.
			newNode->ns = xmlNewNs(newNode, NULL, nodePrefix);
			CHECK_FOR_NULL(newNode->ns);
		}
	}
	
	// Process all the attributes
	for (i = 0, j = 0; j < nb_attributes; j++)
	{
		const xmlChar *attrName   = attributes[i++];
		const xmlChar *attrPrefix = attributes[i++];
		const xmlChar *attrUri    = attributes[i++];
		const xmlChar *valueBegin = attributes[i++];
		const xmlChar *valueEnd   = attributes[i++];
		
		xmlChar *value = xmlStrndup(valueBegin, valueEnd - valueBegin);
		CHECK_FOR_NULL(value);
		
		if ((attrPrefix == NULL) && (attrUri == NULL))
		{
			// Normal attribute - no associated namespace
			xmlAttrPtr newAttr = xmlNewProp(newNode, attrName, value);
			CHECK_FOR_NULL(newAttr);
		}
		else
		{
			// Find the namespace for the attribute
			xmlNsPtr attrNs = xmlSearchNs(ctxt->myDoc, newNode, attrPrefix);
			
			if(attrNs != NULL)
			{
				xmlAttrPtr newAttr = xmlNewNsProp(newNode, attrNs, attrName, value);
				CHECK_FOR_NULL(newAttr);
			}
			else
			{
				attrNs = xmlNewNs(NULL, NULL, nodePrefix);
				CHECK_FOR_NULL(attrNs);
				
				xmlAttrPtr newAttr = xmlNewNsProp(newNode, attrNs, attrName, value);
				CHECK_FOR_NULL(newAttr);
			}
		}
		
		xmlFree(value);
	}
	
	// Update our parent node pointer
	ctxt->node = newNode;
	
	// Invoke delegate methods if needed
	postStartElement(ctxt);
}

/**
 * SAX parser C-style callback.
 * Invoked when characters are found within a node.
**/
static void xmlCharacters(void *ctx, const xmlChar *ch, int len)
{
	xmlParserCtxt *ctxt = (xmlParserCtxt *)ctx;
	
	if(ctxt->node != NULL)
	{
		xmlNodePtr textNode = xmlNewTextLen(ch, len);
		
		// xmlAddChild(xmlNodePtr parent, xmlNodePtr cur)
		// 
		// Add a new node to @parent, at the end of the child list
		// merging adjacent TEXT nodes (in which case @cur is freed).
		
		xmlAddChild(ctxt->node, textNode);
	}
}

/**
 * SAX parser C-style callback.
 * Invoked when a new node element is ended.
**/
static void xmlEndElement(void *ctx, const xmlChar *localname,
                                     const xmlChar *prefix,
                                     const xmlChar *URI)
{
	xmlParserCtxt *ctxt = (xmlParserCtxt *)ctx;
	
	// Update our parent node pointer
	if(ctxt->node != NULL)
		ctxt->node = ctxt->node->parent;
	
	// Invoke delegate methods if needed
	postEndElement(ctxt);
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
		
		saxHandler.initialized = XML_SAX2_MAGIC;
		saxHandler.startElementNs = xmlStartElement;
		saxHandler.characters = xmlCharacters;
		saxHandler.endElementNs = xmlEndElement;
		
		// Create the push parser context
		parserCtxt = xmlCreatePushParserCtxt(&saxHandler, NULL, NULL, 0, NULL);
		
		// Note: This method copies the saxHandler, so we don't have to keep it around.
		
		// Create the document to hold the parsed elements
		parserCtxt->myDoc = xmlNewDoc(parserCtxt->version);
		
		// Store reference to ourself
		parserCtxt->_private = self;
		
		// Note: The parserCtxt also has a userData variable, but it is used by the DOM building functions.
		// If we put a value there, it actually causes a crash!
		// We need to be sure to use the _private variable which libxml won't touch.
	}
	return self;
}

- (void)dealloc
{
	if(parserCtxt)
	{
		// The xmlFreeParserCtxt method will not free the created document in parserCtxt->myDoc.
		
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
