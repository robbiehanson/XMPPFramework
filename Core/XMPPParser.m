#import "XMPPParser.h"
#import <libxml/parserInternals.h>

#if TARGET_OS_IPHONE
  #import "DDXMLPrivate.h"
#endif

#define CHECK_FOR_NULL(value) do { if(value == NULL) { xmlAbortDueToMemoryShortage(ctxt); return; } } while(false)

#if !TARGET_OS_IPHONE
  static void recursiveAddChild(NSXMLElement *parent, xmlNodePtr childNode);
#endif


@implementation XMPPParser

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark iPhone
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#if TARGET_OS_IPHONE

static void onDidReadRoot(XMPPParser *parser, xmlNodePtr root)
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
	
	[parser performSelector:@selector(streamThread_DidReadRoot:)
	               onThread:parser->streamThread
	             withObject:rootCopyWrapper
	          waitUntilDone:NO];
	
	// Note: DDXMLElement will properly free the node when it is deallocated.
}

static void onDidReadElement(XMPPParser *parser, xmlNodePtr child)
{
	DDXMLElement *childWrapper = [DDXMLElement nodeWithPrimitive:(xmlKindPtr)child];
	[childWrapper detach];
	
	// Note: We always want to detach the child from the root.
	// This prevents the doc from growing infinitely large.
	
	[parser performSelector:@selector(streamThread_DidReadElement:)
	               onThread:parser->streamThread
	             withObject:childWrapper
	          waitUntilDone:NO];
	
	// Note: DDXMLElement will properly free the node when it is deallocated.
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Mac
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#else

static void setName(NSXMLElement *element, xmlNodePtr node)
{
	// Remember: The NSString initWithUTF8String raises an exception if passed NULL
	
	if(node->name == NULL)
	{
		[element setName:@""];
		return;
	}
	
	if((node->ns != NULL) && (node->ns->prefix != NULL))
	{
		// E.g: <deusty:element xmlns:deusty="deusty.com"/>
		
		NSString *prefix = [[NSString alloc] initWithUTF8String:(const char *)node->ns->prefix];
		NSString *name   = [[NSString alloc] initWithUTF8String:(const char *)node->name];
		
		NSString *elementName = [[NSString alloc] initWithFormat:@"%@:%@", prefix, name];
		[element setName:elementName];
		[elementName release];
		
		[name release];
		[prefix release];
	}
	else
	{
		NSString *elementName = [[NSString alloc] initWithUTF8String:(const char *)node->name];
		[element setName:elementName];
		[elementName release];
	}
}

static void addNamespaces(NSXMLElement *element, xmlNodePtr node)
{
	// Remember: The NSString initWithUTF8String raises an exception if passed NULL
	
	xmlNsPtr nsNode = node->nsDef;
	while(nsNode != NULL)
	{
		if(nsNode->href == NULL)
		{
			// Namespace doesn't have a value!
		}
		else
		{
			NSXMLNode *ns = [[NSXMLNode alloc] initWithKind:NSXMLNamespaceKind];
			
			if(nsNode->prefix != NULL)
			{
				NSString *nsName = [[NSString alloc] initWithUTF8String:(const char *)nsNode->prefix];
				[ns setName:nsName];
				[nsName release];
			}
			else
			{
				// Default namespace.
				// E.g: xmlns="deusty.com"
				
				[ns setName:@""];
			}
			
			NSString *nsValue = [[NSString alloc] initWithUTF8String:(const char *)nsNode->href];
			[ns setStringValue:nsValue];
			[nsValue release];
			
			[element addNamespace:ns];
			[ns release];
		}
		
		nsNode = nsNode->next;
	}
}

static void addChildren(NSXMLElement *element, xmlNodePtr node)
{
	// Remember: The NSString initWithUTF8String raises an exception if passed NULL
	
	xmlNodePtr childNode = node->children;
	while(childNode != NULL)
	{
		if(childNode->type == XML_ELEMENT_NODE)
		{
			recursiveAddChild(element, childNode);
		}
		else if(childNode->type == XML_TEXT_NODE)
		{
			if(childNode->content != NULL)
			{
				NSString *value = [[NSString alloc] initWithUTF8String:(const char *)childNode->content];
				[element setStringValue:value];
				[value release];
			}
		}
		
		childNode = childNode->next;
	}
}

static void addAttributes(NSXMLElement *element, xmlNodePtr node)
{
	// Remember: The NSString initWithUTF8String raises an exception if passed NULL
	
	xmlAttrPtr attrNode = node->properties;
	while(attrNode != NULL)
	{
		if(attrNode->name == NULL)
		{
			// Attribute doesn't have a name!
		}
		else if(attrNode->children == NULL)
		{
			// Attribute doesn't have a value node!
		}
		else if(attrNode->children->content == NULL)
		{
			// Attribute doesn't have a value!
		}
		else
		{
			NSXMLNode *attr = [[NSXMLNode alloc] initWithKind:NSXMLAttributeKind];
			
			if((attrNode->ns != NULL) && (attrNode->ns->prefix != NULL))
			{
				// E.g: <element xmlns:deusty="deusty.com" deusty:attr="value"/>
				
				NSString *prefix = [[NSString alloc] initWithUTF8String:(const char *)attrNode->ns->prefix];
				NSString *name   = [[NSString alloc] initWithUTF8String:(const char *)attrNode->name];
				
				NSString *attrName = [[NSString alloc] initWithFormat:@"%@:%@", prefix, name];
				[attr setName:attrName];
				[attrName release];
				
				[name release];
				[prefix release];
			}
			else
			{
				NSString *attrName = [[NSString alloc] initWithUTF8String:(const char *)attrNode->name];
				[attr setName:attrName];
				[attrName release];
			}
			
			NSString *attrValue = [[NSString alloc] initWithUTF8String:(const char *)attrNode->children->content];
			[attr setStringValue:attrValue];
			[attrValue release];
			
			[element addAttribute:attr];
			[attr release];
		}
		
		attrNode = attrNode->next;
	}
}

/**
 * Recursively adds all the child elements to the given parent.
 * 
 * Note: This method is almost the same as nsxmlFromLibxml, with one important difference.
 * It doen't add any objects to the autorelease pool.
**/
static void recursiveAddChild(NSXMLElement *parent, xmlNodePtr childNode)
{
	// Remember: The NSString initWithUTF8String raises an exception if passed NULL
	
	NSXMLElement *child = [[NSXMLElement alloc] initWithKind:NSXMLElementKind];
	
	setName(child, childNode);
	
	addNamespaces(child, childNode);
	
	addChildren(child, childNode);
	addAttributes(child, childNode);
	
	[parent addChild:child];
	[child release];
}

/**
 * Creates and returns an NSXMLElement from the given node.
 * Use this method after finding the root element, or root.child element.
**/
static NSXMLElement* nsxmlFromLibxml(xmlNodePtr rootNode)
{
	// Remember: The NSString initWithUTF8String raises an exception if passed NULL
	
	NSXMLElement *root = [[NSXMLElement alloc] initWithKind:NSXMLElementKind];
	
	setName(root, rootNode);
	
	addNamespaces(root, rootNode);
	
	addChildren(root, rootNode);
	addAttributes(root, rootNode);
	
	return [root autorelease];
}

static void onDidReadRoot(XMPPParser *parser, xmlNodePtr root)
{
	NSXMLElement *nsRoot = nsxmlFromLibxml(root);
	
	[parser performSelector:@selector(streamThread_DidReadRoot:)
	               onThread:parser->streamThread
	             withObject:nsRoot
	          waitUntilDone:NO];
}

static void onDidReadElement(XMPPParser *parser, xmlNodePtr child)
{
	NSXMLElement *nsChild = nsxmlFromLibxml(child);
	
	[parser performSelector:@selector(streamThread_DidReadElement:)
	               onThread:parser->streamThread
	             withObject:nsChild
	          waitUntilDone:NO];
	
	// Note: We always want to detach the child from the root.
	// This prevents the doc from growing infinitely large.
	
	// Detach and free child to keep memory footprint small
	xmlUnlinkNode(child);
	xmlFreeNode(child);
}

#endif

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Common
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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
				onDidReadRoot(parser, root);
				
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
				onDidReadElement(parser, child);
				
				// Exit while loop
				break;
			}
			
			child = child->next;
		}
	}
	else if(parser->depth == 0)
	{
		// End of the root element
		
		[parser performSelector:@selector(streamThread_DidEnd)
		               onThread:parser->streamThread
		             withObject:nil
		          waitUntilDone:NO];
	}
}

/**
 * We're screwed...
**/
static void xmlAbortDueToMemoryShortage(xmlParserCtxt *ctxt)
{
	XMPPParser *parser = (XMPPParser *)ctxt->_private;
	
	xmlStopParser(ctxt);
	
	NSString *errMsg = @"Unable to allocate memory in xmpp parser";
	NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
	
	NSError *error = [NSError errorWithDomain:@"libxmlErrorDomain" code:1001 userInfo:info];
	
	[parser performSelector:@selector(streamThread_DidFail:)
	               onThread:parser->streamThread
	             withObject:error
	          waitUntilDone:NO];
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
	xmlNsPtr lastAddedNs = NULL;
	
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
		else if(lastAddedNs)
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
		
        // The attribute value might contain character references which need to be decoded.
        // 
        // "Franks &#38; Beans" -> "Franks & Beans"
        
		xmlChar *value = xmlStringLenDecodeEntities(ctxt,                    // the parser context
		                                            valueBegin,              // the input string
		                                      (int)(valueEnd - valueBegin),  // the input string length
		                                           (XML_SUBSTITUTE_REF),     // what to substitue
		                                            0, 0, 0);                // end markers, 0 if none
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
		
		// Setup threading
		
		stopped = NO;
		
		streamThread = [[NSThread currentThread] retain];
		
		parsingThread = [[NSThread alloc] initWithTarget:self selector:@selector(parsingThread_Main) object:nil];
		[parsingThread start];
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
	
	[streamThread release];
	[parsingThread release];
	
	[super dealloc];
}

- (void)parseData:(NSData *)data
{
	[self performSelector:@selector(parsingThread_Parse:) onThread:parsingThread withObject:data waitUntilDone:NO];
}

- (void)stop
{
	stopped = YES;
	delegate = nil;
	
	[self performSelector:@selector(parsingThread_Stop) onThread:parsingThread withObject:nil waitUntilDone:NO];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Threading
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)parsingThread_Main
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	// We can't run the run loop unless it has an associated input source or a timer.
	// So we'll just create a timer that will never fire - unless the server runs for 10,000 years.
	[NSTimer scheduledTimerWithTimeInterval:DBL_MAX target:self selector:@selector(ignore:) userInfo:nil repeats:NO];
	
	// Run the runloop
	
	BOOL allIsWell = YES;
	while(!stopped && allIsWell)
	{
		NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
		
		allIsWell = [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
		                                     beforeDate:[NSDate dateWithTimeIntervalSinceNow:3600.0]];
		[innerPool release];
	}
	
	[pool release];
}

- (void)parsingThread_Stop
{
	// Nothing to do here.
	// However, this will cause the runloop to return, and the thread to terminate.
}

- (void)parsingThread_Parse:(NSData *)data
{
	int result = xmlParseChunk(parserCtxt, (const char *)[data bytes], (int)[data length], 0);
	
	if(result != 0)
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
		
		[self performSelector:@selector(streamThread_DidFail:)
		             onThread:streamThread
		           withObject:error
		        waitUntilDone:NO];
	}
	
	NSNumber *length = [NSNumber numberWithUnsignedInteger:[data length]];
	
	[self performSelector:@selector(streamThread_DidParseDataOfLength:)
	             onThread:streamThread
	           withObject:length
	        waitUntilDone:NO];
}

- (void)streamThread_DidReadRoot:(NSXMLElement *)root
{
	if ([delegate respondsToSelector:@selector(xmppParser:didReadRoot:)])
	{
		[delegate xmppParser:self didReadRoot:root];
	}
}

- (void)streamThread_DidReadElement:(NSXMLElement *)element
{
	if ([delegate respondsToSelector:@selector(xmppParser:didReadElement:)])
	{
		[delegate xmppParser:self didReadElement:element];
	}
}

- (void)streamThread_DidEnd
{
	if ([delegate respondsToSelector:@selector(xmppParserDidEnd:)])
	{
		[delegate xmppParserDidEnd:self];
	}
}

- (void)streamThread_DidFail:(NSError *)error
{
	if ([delegate respondsToSelector:@selector(xmppParser:didFail:)])
	{
		[delegate xmppParser:self didFail:error];
	}
}

- (void)streamThread_DidParseDataOfLength:(NSNumber *)number
{
	if ([delegate respondsToSelector:@selector(xmppParser:didParseDataOfLength:)])
	{
		NSUInteger length = [number unsignedIntegerValue];
		
		[delegate xmppParser:self didParseDataOfLength:length];
	}
}

@end
