#import "XMPPParser.h"
#import "XMPPLogging.h"
#import <libxml/parser.h>
#import <libxml/parserInternals.h>

#if TARGET_OS_IPHONE
  #import "DDXMLPrivate.h"
#endif

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

// Log levels: off, error, warn, info, verbose
#if DEBUG
  static const int xmppLogLevel = XMPP_LOG_LEVEL_VERBOSE;
#else
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

#define CHECK_FOR_NULL(value)                       \
    do {                                            \
        if (value == NULL) {                        \
            xmpp_xmlAbortDueToMemoryShortage(ctxt); \
            return;                                 \
        }                                           \
    } while(false)

#if !TARGET_OS_IPHONE
  static void xmpp_recursiveAddChild(NSXMLElement *parent, xmlNodePtr childNode);
#endif

@implementation XMPPParser
{
	#if __has_feature(objc_arc_weak)
	__weak id delegate;
	#else
	__unsafe_unretained id delegate;
	#endif
	dispatch_queue_t delegateQueue;
	
	dispatch_queue_t parserQueue;
	void *xmppParserQueueTag;
	
	BOOL hasReportedRoot;
	unsigned depth;
	
	xmlParserCtxt *parserCtxt;
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark iPhone
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#if TARGET_OS_IPHONE

static void xmpp_onDidReadRoot(XMPPParser *parser, xmlNodePtr root)
{
	if (parser->delegateQueue && [parser->delegate respondsToSelector:@selector(xmppParser:didReadRoot:)])
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
		DDXMLElement *rootCopyWrapper = [DDXMLElement nodeWithElementPrimitive:rootCopy owner:nil];
		
		__strong id theDelegate = parser->delegate;
		
		dispatch_async(parser->delegateQueue, ^{ @autoreleasepool {
			
			[theDelegate xmppParser:parser didReadRoot:rootCopyWrapper];
		}});

		// Note: DDXMLElement will properly free the rootCopy when it's deallocated.
	}
}

static void xmpp_onDidReadElement(XMPPParser *parser, xmlNodePtr child)
{
	// Detach the child from the xml tree.
	// 
	// clean: Nullify next, prev, parent and doc pointers of child.
	// fixNamespaces: Recurse through subtree, and ensure no namespaces are pointing to xmlNs nodes outside the tree.
	//                E.G. in a parent node that will no longer be available after the child is detached.
	// 
	// We don't need to fix namespaces since we used xmpp_xmlSearchNs() to ensure we never created any
	// namespaces outside the subtree of the child in the first place.
	
	[DDXMLNode detachChild:child andClean:YES andFixNamespaces:NO];
	
	DDXMLElement *childWrapper = [DDXMLElement nodeWithElementPrimitive:child owner:nil];
	
	// Note: We want to detach the child from the root even if the delegate method isn't setup.
	// This prevents the doc from growing infinitely large.
	
	if (parser->delegateQueue && [parser->delegate respondsToSelector:@selector(xmppParser:didReadElement:)])
	{
		__strong id theDelegate = parser->delegate;
		
		dispatch_async(parser->delegateQueue, ^{ @autoreleasepool {
			
			[theDelegate xmppParser:parser didReadElement:childWrapper];
		}});
	}
	
	// Note: DDXMLElement will properly free the child when it's deallocated.
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Mac
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#else

static void xmpp_setName(NSXMLElement *element, xmlNodePtr node)
{
	// Remember: The NSString initWithUTF8String raises an exception if passed NULL
	
	if (node->name == NULL)
	{
		[element setName:@""];
		return;
	}
	
	if ((node->ns != NULL) && (node->ns->prefix != NULL))
	{
		// E.g: <deusty:element xmlns:deusty="deusty.com"/>
		
		NSString *prefix = [[NSString alloc] initWithUTF8String:(const char *)node->ns->prefix];
		NSString *name   = [[NSString alloc] initWithUTF8String:(const char *)node->name];
		
		NSString *elementName = [[NSString alloc] initWithFormat:@"%@:%@", prefix, name];
		[element setName:elementName];
		
	}
	else
	{
		NSString *elementName = [[NSString alloc] initWithUTF8String:(const char *)node->name];
		[element setName:elementName];
	}
}

static void xmpp_addNamespaces(NSXMLElement *element, xmlNodePtr node)
{
	// Remember: The NSString initWithUTF8String raises an exception if passed NULL
	
	xmlNsPtr nsNode = node->nsDef;
	while (nsNode != NULL)
	{
		if (nsNode->href == NULL)
		{
			// Namespace doesn't have a value!
		}
		else
		{
			NSXMLNode *ns = [[NSXMLNode alloc] initWithKind:NSXMLNamespaceKind];
			
			if (nsNode->prefix != NULL)
			{
				NSString *nsName = [[NSString alloc] initWithUTF8String:(const char *)nsNode->prefix];
				[ns setName:nsName];
			}
			else
			{
				// Default namespace.
				// E.g: xmlns="deusty.com"
				
				[ns setName:@""];
			}
			
			NSString *nsValue = [[NSString alloc] initWithUTF8String:(const char *)nsNode->href];
			[ns setStringValue:nsValue];
			
			[element addNamespace:ns];
		}
		
		nsNode = nsNode->next;
	}
}

static void xmpp_addChildren(NSXMLElement *element, xmlNodePtr node)
{
	// Remember: The NSString initWithUTF8String raises an exception if passed NULL
	
	xmlNodePtr childNode = node->children;
	while (childNode != NULL)
	{
		if (childNode->type == XML_ELEMENT_NODE)
		{
			xmpp_recursiveAddChild(element, childNode);
		}
		else if (childNode->type == XML_TEXT_NODE)
		{
			if (childNode->content != NULL)
			{
				NSString *value = [[NSString alloc] initWithUTF8String:(const char *)childNode->content];
				[element setStringValue:value];
			}
		}
		
		childNode = childNode->next;
	}
}

static void xmpp_addAttributes(NSXMLElement *element, xmlNodePtr node)
{
	// Remember: The NSString initWithUTF8String raises an exception if passed NULL
	
	xmlAttrPtr attrNode = node->properties;
	while (attrNode != NULL)
	{
		if (attrNode->name == NULL)
		{
			// Attribute doesn't have a name!
		}
		else if (attrNode->children == NULL)
		{
			// Attribute doesn't have a value node!
		}
		else if (attrNode->children->content == NULL)
		{
			// Attribute doesn't have a value!
		}
		else
		{
			NSXMLNode *attr = [[NSXMLNode alloc] initWithKind:NSXMLAttributeKind];
			
			if ((attrNode->ns != NULL) && (attrNode->ns->prefix != NULL))
			{
				// E.g: <element xmlns:deusty="deusty.com" deusty:attr="value"/>
				
				NSString *prefix = [[NSString alloc] initWithUTF8String:(const char *)attrNode->ns->prefix];
				NSString *name   = [[NSString alloc] initWithUTF8String:(const char *)attrNode->name];
				
				NSString *attrName = [[NSString alloc] initWithFormat:@"%@:%@", prefix, name];
				[attr setName:attrName];
				
			}
			else
			{
				NSString *attrName = [[NSString alloc] initWithUTF8String:(const char *)attrNode->name];
				[attr setName:attrName];
			}
			
			NSString *attrValue = [[NSString alloc] initWithUTF8String:(const char *)attrNode->children->content];
			[attr setStringValue:attrValue];
			
			[element addAttribute:attr];
		}
		
		attrNode = attrNode->next;
	}
}

/**
 * Recursively adds all the child elements to the given parent.
 * 
 * Note: This method is almost the same as xmpp_nsxmlFromLibxml, with one important difference.
 * It doen't add any objects to the autorelease pool (xmpp_nsxmlFromLibXml has return value).
**/
static void xmpp_recursiveAddChild(NSXMLElement *parent, xmlNodePtr childNode)
{
	// Remember: The NSString initWithUTF8String raises an exception if passed NULL
	
	NSXMLElement *child = [[NSXMLElement alloc] initWithKind:NSXMLElementKind];
	
	xmpp_setName(child, childNode);
	
	xmpp_addNamespaces(child, childNode);
	
	xmpp_addChildren(child, childNode);
	xmpp_addAttributes(child, childNode);
	
	[parent addChild:child];
}

/**
 * Creates and returns an NSXMLElement from the given node.
 * Use this method after finding the root element, or root.child element.
**/
static NSXMLElement* xmpp_nsxmlFromLibxml(xmlNodePtr rootNode)
{
	// Remember: The NSString initWithUTF8String raises an exception if passed NULL
	
	NSXMLElement *root = [[NSXMLElement alloc] initWithKind:NSXMLElementKind];
	
	xmpp_setName(root, rootNode);
	
	xmpp_addNamespaces(root, rootNode);
	
	xmpp_addChildren(root, rootNode);
	xmpp_addAttributes(root, rootNode);
	
	return root;
}

static void xmpp_onDidReadRoot(XMPPParser *parser, xmlNodePtr root)
{
	if (parser->delegateQueue && [parser->delegate respondsToSelector:@selector(xmppParser:didReadRoot:)])
	{
		NSXMLElement *nsRoot = xmpp_nsxmlFromLibxml(root);
		
		__strong id theDelegate = parser->delegate;
		
		dispatch_async(parser->delegateQueue, ^{ @autoreleasepool {
			
			[theDelegate xmppParser:parser didReadRoot:nsRoot];
		}});
	}
}

static void xmpp_onDidReadElement(XMPPParser *parser, xmlNodePtr child)
{
	if (parser->delegateQueue && [parser->delegate respondsToSelector:@selector(xmppParser:didReadElement:)])
	{
		NSXMLElement *nsChild = xmpp_nsxmlFromLibxml(child);
		
		__strong id theDelegate = parser->delegate;
		
		dispatch_async(parser->delegateQueue, ^{ @autoreleasepool {
		
			[theDelegate xmppParser:parser didReadElement:nsChild];
		}});
	}
	
	// Note: We want to detach the child from the root even if the delegate method isn't setup.
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
static void xmpp_postStartElement(xmlParserCtxt *ctxt)
{
	XMPPParser *parser = (__bridge XMPPParser *)ctxt->_private;
	parser->depth++;
	
	if (!(parser->hasReportedRoot) && (parser->depth == 1))
	{
		// We've received the full root - report it to the delegate
		
		if (ctxt->myDoc)
		{
			xmlNodePtr root = xmlDocGetRootElement(ctxt->myDoc);
			if (root)
			{
				xmpp_onDidReadRoot(parser, root);
				
				parser->hasReportedRoot = YES;
			}
		}
	}
}

/**
 * This method is called at the end of the xmlEndElement method.
 * This allows us to inspect the parser and xml tree, and determine if we need to invoke any delegate methods.
**/
static void xmpp_postEndElement(xmlParserCtxt *ctxt)
{
	XMPPParser *parser = (__bridge XMPPParser *)ctxt->_private;
	parser->depth--;
	
	if (parser->depth == 1)
	{
		// End of full xmpp element.
		// That is, a child of the root element.
		// Extract the child, and pass it to the delegate.
		
		xmlDocPtr doc = ctxt->myDoc;
		xmlNodePtr root = xmlDocGetRootElement(doc);
		
		xmlNodePtr child = root->children;
		while (child != NULL)
		{
			if (child->type == XML_ELEMENT_NODE)
			{
				xmpp_onDidReadElement(parser, child);
				
				// Exit while loop
				break;
			}
			
			child = child->next;
		}
	}
	else if (parser->depth == 0)
	{
		// End of the root element
		
		if (parser->delegateQueue && [parser->delegate respondsToSelector:@selector(xmppParserDidEnd:)])
		{
			__strong id theDelegate = parser->delegate;
			
			dispatch_async(parser->delegateQueue, ^{ @autoreleasepool {
			
				[theDelegate xmppParserDidEnd:parser];
			}});
		}
	}
}

/**
 * We're screwed...
**/
static void xmpp_xmlAbortDueToMemoryShortage(xmlParserCtxt *ctxt)
{
	XMPPParser *parser = (__bridge XMPPParser *)ctxt->_private;
	
	xmlStopParser(ctxt);
	
	if (parser->delegateQueue && [parser->delegate respondsToSelector:@selector(xmppParser:didFail:)])
	{
		NSString *errMsg = @"Unable to allocate memory in xmpp parser";
		NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
		
		NSError *error = [NSError errorWithDomain:@"libxmlErrorDomain" code:1001 userInfo:info];
		
		__strong id theDelegate = parser->delegate;
		
		dispatch_async(parser->delegateQueue, ^{ @autoreleasepool {
			
			[theDelegate xmppParser:parser didFail:error];
		}});
	}
}

/**
 * (Similar to the libxml "xmlSearchNs" method, with one very important difference.)
 * 
 * This method searches for an existing xmlNsPtr in the given node,
 * recursing on the parents but stopping before it reaches the root node of the document.
 * 
 * Why do we skip the root node?
 * Because all nodes are going to be detached from the root node.
 * So it makes no sense to allow them to reference namespaces stored in the root node,
 * since the detach algorithm will be forced to copy the namespaces later anyway.
**/
static xmlNsPtr xmpp_xmlSearchNs(xmlDocPtr doc, xmlNodePtr node, const xmlChar *nameSpace)
{
	xmlNodePtr rootNode = xmlDocGetRootElement(doc);
	
	xmlNodePtr currentNode = node;
	while (currentNode && currentNode != rootNode)
	{
		xmlNsPtr currentNs = currentNode->nsDef;
		while (currentNs)
		{
			if (currentNs->href != NULL)
			{
				if ((currentNs->prefix == NULL) && (nameSpace == NULL))
				{
					return currentNs;
				}
				if ((currentNs->prefix != NULL) && (nameSpace != NULL))
				{
					if (xmlStrEqual(currentNs->prefix, nameSpace))
						return currentNs;
				}
			}
			
			currentNs = currentNs->next;
		}
		
		currentNode = currentNode->parent;
	}
	
	return NULL;
}

/**
 * SAX parser C-style callback.
 * Invoked when a new node element is started.
**/
static void	xmpp_xmlStartElement(void *ctx, const xmlChar  *nodeName,
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
	if (parent == NULL)
	{
		// Root node
		xmlAddChild((xmlNodePtr)ctxt->myDoc, newNode);
	}
	else
	{
		xmlAddChild(parent, newNode);
	}
	
	// Process the namespaces
	for (i = 0, j = 0; j < nb_namespaces; j++)
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
			newNode->nsDef = newNs;
			lastAddedNs = newNs;
		}
		else
		{
            if(lastAddedNs != NULL)
            {
                lastAddedNs->next = newNs;
            }
            
			lastAddedNs = newNs;
		}
		
		// Is this the namespace for the node?
		
		if (nodeUri && (nodePrefix == nsPrefix))
		{
			// Ex 1: node == <stream:stream xmlns:stream="url"> && newNs == stream:url
			// Ex 2: node == <starttls xmlns="url">             && newNs == null:url
			
			newNode->ns = newNs;
		}
	}
	
	// Search for the node's namespace if it wasn't already found
	if ((nodeUri) && (newNode->ns == NULL))
	{
		newNode->ns = xmpp_xmlSearchNs(ctxt->myDoc, newNode, nodePrefix);
		
		if (newNode->ns == NULL)
		{
			// We use href==NULL in the case of an element creation where the namespace was not defined.
			// 
			// We do NOT use xmlNewNs(newNode, nodeUri, nodePrefix) because that method doesn't properly add
			// the namespace to BOTH nsDef and ns.
			
			xmlNsPtr newNs = xmlNewNs(NULL, nodeUri, nodePrefix);
			CHECK_FOR_NULL(newNs);
			
			if (newNode->nsDef == NULL)
			{
				newNode->nsDef = newNs;
			}
			else if(lastAddedNs != NULL)
			{
				lastAddedNs->next = newNs;
			}
			
			newNode->ns = newNs;
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
			xmlNsPtr attrNs = xmpp_xmlSearchNs(ctxt->myDoc, newNode, attrPrefix);
			
			if (attrNs != NULL)
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
	xmpp_postStartElement(ctxt);
}

/**
 * SAX parser C-style callback.
 * Invoked when characters are found within a node.
**/
static void xmpp_xmlCharacters(void *ctx, const xmlChar *ch, int len)
{
	xmlParserCtxt *ctxt = (xmlParserCtxt *)ctx;
	
	if (ctxt->node != NULL)
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
static void xmpp_xmlEndElement(void *ctx, const xmlChar *localname,
                                          const xmlChar *prefix,
                                          const xmlChar *URI)
{
	xmlParserCtxt *ctxt = (xmlParserCtxt *)ctx;
	
	// Update our parent node pointer
	if (ctxt->node != NULL)
		ctxt->node = ctxt->node->parent;
	
	// Invoke delegate methods if needed
	xmpp_postEndElement(ctxt);
}

- (id)initWithDelegate:(id)aDelegate delegateQueue:(dispatch_queue_t)dq
{
	return [self initWithDelegate:aDelegate delegateQueue:dq parserQueue:NULL];
}

- (id)initWithDelegate:(id)aDelegate delegateQueue:(dispatch_queue_t)dq parserQueue:(dispatch_queue_t)pq
{
	if ((self = [super init]))
	{
		delegate = aDelegate;
		delegateQueue = dq;
		
		#if !OS_OBJECT_USE_OBJC
		if (delegateQueue)
			dispatch_retain(delegateQueue);
		#endif

		if (pq) {
			parserQueue = pq;
			
			#if !OS_OBJECT_USE_OBJC
			dispatch_retain(parserQueue);
			#endif
		}
		else {
			parserQueue = dispatch_queue_create("xmpp.parser", NULL);
		}
		
		xmppParserQueueTag = &xmppParserQueueTag;
		dispatch_queue_set_specific(parserQueue, xmppParserQueueTag, xmppParserQueueTag, NULL);
		
		hasReportedRoot = NO;
		depth  = 0;
		
		// Create SAX handler
		xmlSAXHandler saxHandler;
		memset(&saxHandler, 0, sizeof(xmlSAXHandler));
		
		saxHandler.initialized = XML_SAX2_MAGIC;
		saxHandler.startElementNs = xmpp_xmlStartElement;
		saxHandler.characters = xmpp_xmlCharacters;
		saxHandler.endElementNs = xmpp_xmlEndElement;
		
		// Create the push parser context
		parserCtxt = xmlCreatePushParserCtxt(&saxHandler, NULL, NULL, 0, NULL);
		
		// Note: This method copies the saxHandler, so we don't have to keep it around.
		
		// Create the document to hold the parsed elements
		parserCtxt->myDoc = xmlNewDoc(parserCtxt->version);
		
		// Store reference to ourself
		parserCtxt->_private = (__bridge void *)(self);
		
		// Note: The parserCtxt also has a userData variable, but it is used by the DOM building functions.
		// If we put a value there, it actually causes a crash!
		// We need to be sure to use the _private variable which libxml won't touch.
	}
	return self;
}

- (void)dealloc
{
	if (parserCtxt)
	{
		// The xmlFreeParserCtxt method will not free the created document in parserCtxt->myDoc.
		if (parserCtxt->myDoc)
		{
			// Free the created xmlDoc
			xmlFreeDoc(parserCtxt->myDoc);
		}
		
		xmlFreeParserCtxt(parserCtxt);
	}
	
	#if !OS_OBJECT_USE_OBJC
	if (delegateQueue)
		dispatch_release(delegateQueue);
	if (parserQueue)
		dispatch_release(parserQueue);
	#endif
}

- (void)setDelegate:(id)newDelegate delegateQueue:(dispatch_queue_t)newDelegateQueue
{
	#if !OS_OBJECT_USE_OBJC
	if (newDelegateQueue)
		dispatch_retain(newDelegateQueue);
	#endif
	
	dispatch_block_t block = ^{
		
		delegate = newDelegate;
		
		#if !OS_OBJECT_USE_OBJC
		if (delegateQueue)
			dispatch_release(delegateQueue);
		#endif
		
		delegateQueue = newDelegateQueue;
	};
	
	if (dispatch_get_specific(xmppParserQueueTag))
		block();
	else
		dispatch_async(parserQueue, block);
}

- (void)parseData:(NSData *)data
{
	dispatch_block_t block = ^{ @autoreleasepool {
	
		int result = xmlParseChunk(parserCtxt, (const char *)[data bytes], (int)[data length], 0);
		
		if (result == 0)
		{
			if (delegateQueue && [delegate respondsToSelector:@selector(xmppParserDidParseData:)])
			{
				__strong id theDelegate = delegate;
				
				dispatch_async(delegateQueue, ^{ @autoreleasepool {
					
					[theDelegate xmppParserDidParseData:self];
				}});
			}
		}
		else
		{
			if (delegateQueue && [delegate respondsToSelector:@selector(xmppParser:didFail:)])
			{
				NSError *error;
				
				xmlError *xmlErr = xmlCtxtGetLastError(parserCtxt);
				
				if (xmlErr->message)
				{
					NSString *errMsg = [NSString stringWithFormat:@"%s", xmlErr->message];
					NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
					
					error = [NSError errorWithDomain:@"libxmlErrorDomain" code:xmlErr->code userInfo:info];
				}
				else
				{
					error = [NSError errorWithDomain:@"libxmlErrorDomain" code:xmlErr->code userInfo:nil];
				}
				
				__strong id theDelegate = delegate;
				
				dispatch_async(delegateQueue, ^{ @autoreleasepool {
					
					[theDelegate xmppParser:self didFail:error];
				}});
			}
		}
	}};
	
	if (dispatch_get_specific(xmppParserQueueTag))
		block();
	else
		dispatch_async(parserQueue, block);
}

@end
