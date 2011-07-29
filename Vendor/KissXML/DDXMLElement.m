#import "DDXMLPrivate.h"
#import "NSString+DDXML.h"


@implementation DDXMLElement

/**
 * Returns a DDXML wrapper object for the given primitive node.
 * The given node MUST be non-NULL and of the proper type.
**/
+ (id)nodeWithElementPrimitive:(xmlNodePtr)node owner:(DDXMLNode *)owner
{
	return [[[DDXMLElement alloc] initWithElementPrimitive:node owner:owner] autorelease];
}

- (id)initWithElementPrimitive:(xmlNodePtr)node owner:(DDXMLNode *)inOwner
{
	self = [super initWithPrimitive:(xmlKindPtr)node owner:inOwner];
	return self;
}

+ (id)nodeWithPrimitive:(xmlKindPtr)kindPtr owner:(DDXMLNode *)owner
{
	// Promote initializers which use proper parameter types to enable compiler to catch more mistakes
	NSAssert(NO, @"Use nodeWithElementPrimitive:owner:");
	
	return nil;
}

- (id)initWithPrimitive:(xmlKindPtr)kindPtr owner:(DDXMLNode *)inOwner
{
	// Promote initializers which use proper parameter types to enable compiler to catch more mistakes.
	NSAssert(NO, @"Use initWithElementPrimitive:owner:");
	
	[self release];
	return nil;
}

- (id)initWithName:(NSString *)name
{
	// Note: Make every guarantee that genericPtr is not null
	
	xmlNodePtr node = xmlNewNode(NULL, [name xmlChar]);
	if (node == NULL)
	{
		[self release];
		return nil;
	}
	
	return [self initWithElementPrimitive:node owner:nil];
}

- (id)initWithName:(NSString *)name URI:(NSString *)URI
{
	// Note: Make every guarantee that genericPtr is not null
	
	xmlNodePtr node = xmlNewNode(NULL, [name xmlChar]);
	if (node == NULL)
	{
		[self release];
		return nil;
	}
	
	DDXMLElement *result = [self initWithElementPrimitive:node owner:nil];
	[result setURI:URI];
	
	return result;
}

- (id)initWithName:(NSString *)name stringValue:(NSString *)string
{
	// Note: Make every guarantee that genericPtr is not null
	
	xmlNodePtr node = xmlNewNode(NULL, [name xmlChar]);
	if (node == NULL)
	{
		[self release];
		return nil;
	}
	
	DDXMLElement *result = [self initWithElementPrimitive:node owner:nil];
	[result setStringValue:string];
	
	return result;
}

- (id)initWithXMLString:(NSString *)string error:(NSError **)error
{
	DDXMLDocument *doc = [[DDXMLDocument alloc] initWithXMLString:string options:0 error:error];
	if (doc == nil)
	{
		[self release];
		return nil;
	}
	
	DDXMLElement *result = [doc rootElement];
	[result detach];
	[doc release];
	
	[self release];
	return [result retain];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Elements by name
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Returns the child element nodes (as DDXMLElement objects) of the receiver that have a specified name.
 * 
 * If name is a qualified name, then this method invokes elementsForLocalName:URI: with the URI parameter set to
 * the URI associated with the prefix. Otherwise comparison is based on string equality of the qualified or
 * non-qualified name.
**/
- (NSArray *)elementsForName:(NSString *)name
{
#if DDXML_DEBUG_MEMORY_ISSUES
	DDXMLNotZombieAssert();
#endif
	
	if (name == nil) return [NSArray array];
	
	// We need to check to see if name has a prefix.
	// If it does have a prefix, we need to figure out what the corresponding URI is for that prefix,
	// and then search for any elements that have the same name (including prefix) OR have the same URI.
	// Otherwise we loop through the children as usual and do a string compare on the name
	
	NSString *prefix = [[self class] prefixForName:name];
	if ([prefix length] > 0)
	{
		xmlNodePtr node = (xmlNodePtr)genericPtr;
		xmlNsPtr ns = xmlSearchNs(node->doc, node, [prefix xmlChar]);
		if (ns != NULL)
		{
			NSString *uri = [NSString stringWithUTF8String:((const char *)ns->href)];
			return [self _elementsForName:name uri:uri];
		}
		
		// Note: We used xmlSearchNs instead of resolveNamespaceForName: because
		// we want to avoid creating wrapper objects when possible.
	}
	
	return [self _elementsForName:name uri:nil];
}

- (NSArray *)elementsForLocalName:(NSString *)localName URI:(NSString *)URI
{
#if DDXML_DEBUG_MEMORY_ISSUES
	DDXMLNotZombieAssert();
#endif
	
	if (localName == nil) return [NSArray array];
	
	// We need to figure out what the prefix is for this URI.
	// Then we search for elements that are named prefix:localName OR (named localName AND have the given URI).
	
	NSString *prefix = [self _recursiveResolvePrefixForURI:URI atNode:(xmlNodePtr)genericPtr];
	if (prefix != nil)
	{
		NSString *name = [NSString stringWithFormat:@"%@:%@", prefix, localName];
		
		return [self _elementsForName:name uri:URI];
	}
	else
	{
		return [self _elementsForName:localName uri:URI];
	}
}

/**
 * Helper method elementsForName and elementsForLocalName:URI: so work isn't duplicated.
 * The name parameter is required, URI is optional.
**/
- (NSArray *)_elementsForName:(NSString *)name uri:(NSString *)uri
{
	// This is a private/internal method
	
	// Supplied: name, !uri  : match: name
	// Supplied: p:name, uri : match: p:name || (name && uri)
	// Supplied: name, uri   : match: name && uri
	
	NSMutableArray *result = [NSMutableArray array];
	
	xmlNodePtr node = (xmlNodePtr)genericPtr;
	
	BOOL hasPrefix = [[[self class] prefixForName:name] length] > 0;
	NSString *localName = [[self class] localNameForName:name];
	
	xmlNodePtr child = node->children;
	while (child != NULL)
	{
		if (child->type == XML_ELEMENT_NODE)
		{
			BOOL match = NO;
			if (uri == nil)
			{
				match = xmlStrEqual(child->name, [name xmlChar]);
			}
			else
			{
				BOOL nameMatch = xmlStrEqual(child->name, [name xmlChar]);
				BOOL localNameMatch = xmlStrEqual(child->name, [localName xmlChar]);
				
				BOOL uriMatch = NO;
				if (child->ns != NULL)
				{
					uriMatch = xmlStrEqual(child->ns->href, [uri xmlChar]);
				}
				
				if (hasPrefix)
					match = nameMatch || (localNameMatch && uriMatch);
				else
					match = nameMatch && uriMatch;
			}
			
			if (match)
			{
				[result addObject:[DDXMLElement nodeWithElementPrimitive:child owner:self]];
			}
		}
		
		child = child->next;
	}
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Attributes
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)_hasAttributeWithName:(NSString *)name
{
	// This is a private/internal method
	
	xmlAttrPtr attr = ((xmlNodePtr)genericPtr)->properties;
	if (attr != NULL)
	{
		const xmlChar *xmlName = [name xmlChar];
		
		do
		{
			if (xmlStrEqual(attr->name, xmlName))
			{
				return YES;
			}
			attr = attr->next;
			
		} while (attr != NULL);
	}
	
	return NO;
}

- (void)_removeAttribute:(xmlAttrPtr)attr
{
	// This is a private/internal method
	
	[[self class] removeAttribute:attr fromNode:(xmlNodePtr)genericPtr];
}

- (void)_removeAllAttributes
{
	// This is a private/internal method
	
	[[self class] removeAllAttributesFromNode:(xmlNodePtr)genericPtr];
}

- (void)_removeAttributeForName:(NSString *)name
{
	xmlAttrPtr attr = ((xmlNodePtr)genericPtr)->properties;
	if (attr != NULL)
	{
		const xmlChar *xmlName = [name xmlChar];
		
		do
		{
			if (xmlStrEqual(attr->name, xmlName))
			{
				[self _removeAttribute:attr];
				return;
			}
			attr = attr->next;
			
		} while(attr != NULL);
	}
}

- (void)addAttribute:(DDXMLNode *)attribute
{
#if DDXML_DEBUG_MEMORY_ISSUES
	DDXMLNotZombieAssert();
#endif
	
	// NSXML version uses this same assertion
	DDXMLAssert([attribute _hasParent] == NO, @"Cannot add an attribute with a parent; detach or copy first");
	DDXMLAssert(IsXmlAttrPtr(attribute->genericPtr), @"Not an attribute");
	
	[self _removeAttributeForName:[attribute name]];
	
	// xmlNodePtr xmlAddChild(xmlNodePtr parent, xmlNodePtr cur)
	// Add a new node to @parent, at the end of the child (or property) list merging
	// adjacent TEXT nodes (in which case @cur is freed). If the new node is ATTRIBUTE, it is added
	// into properties instead of children. If there is an attribute with equal name, it is first destroyed.
	
	xmlAddChild((xmlNodePtr)genericPtr, (xmlNodePtr)attribute->genericPtr);
	
	// The attribute is now part of the xml tree heirarchy
	[attribute->owner release];
	attribute->owner = [self retain];
}

- (void)removeAttributeForName:(NSString *)name
{
#if DDXML_DEBUG_MEMORY_ISSUES
	DDXMLNotZombieAssert();
#endif
	
	[self _removeAttributeForName:name];
}

- (NSArray *)attributes
{
#if DDXML_DEBUG_MEMORY_ISSUES
	DDXMLNotZombieAssert();
#endif
	
	NSMutableArray *result = [NSMutableArray array];
	
	xmlAttrPtr attr = ((xmlNodePtr)genericPtr)->properties;
	while (attr != NULL)
	{
		[result addObject:[DDXMLAttributeNode nodeWithAttrPrimitive:attr owner:self]];
		
		attr = attr->next;
	}
	
	return result;
}

- (DDXMLNode *)attributeForName:(NSString *)name
{
#if DDXML_DEBUG_MEMORY_ISSUES
	DDXMLNotZombieAssert();
#endif
	
	const xmlChar *attrName = [name xmlChar];
	
	xmlAttrPtr attr = ((xmlNodePtr)genericPtr)->properties;
	while (attr != NULL)
	{
		if (attr->ns && attr->ns->prefix)
		{
			// If the attribute name was originally something like "xml:quack",
			// then attr->name is "quack" and attr->ns->prefix is "xml".
			// 
			// So if the user is searching for "xml:quack" we need to take the prefix into account.
			// Note that "xml:quack" is what would be printed if we output the attribute.
			
			if (xmlStrQEqual(attr->ns->prefix, attr->name, attrName))
			{
				return [DDXMLAttributeNode nodeWithAttrPrimitive:attr owner:self];
			}
		}
		else
		{
			if (xmlStrEqual(attr->name, attrName))
			{
				return [DDXMLAttributeNode nodeWithAttrPrimitive:attr owner:self];
			}
		}
		
		attr = attr->next;
	}
	return nil;
}

/**
 * Sets the list of attributes for the element.
 * Any previously set attributes are removed.
**/
- (void)setAttributes:(NSArray *)attributes
{
#if DDXML_DEBUG_MEMORY_ISSUES
	DDXMLNotZombieAssert();
#endif
	
	[self _removeAllAttributes];
	
	NSUInteger i;
	for (i = 0; i < [attributes count]; i++)
	{
		DDXMLNode *attribute = [attributes objectAtIndex:i];
		[self addAttribute:attribute];
		
		// Note: The addAttributes method properly sets the freeOnDealloc ivar.
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Namespaces
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)_removeNamespace:(xmlNsPtr)ns
{
	// This is a private/internal method
	
	[[self class] removeNamespace:ns fromNode:(xmlNodePtr)genericPtr];
}

- (void)_removeAllNamespaces
{
	// This is a private/internal method
	
	[[self class] removeAllNamespacesFromNode:(xmlNodePtr)genericPtr];
}

- (void)_removeNamespaceForPrefix:(NSString *)name
{
	// If name is nil or the empty string, the user is wishing to remove the default namespace
	const xmlChar *xmlName = [name length] > 0 ? [name xmlChar] : NULL;
	
	xmlNsPtr ns = ((xmlNodePtr)genericPtr)->nsDef;
	while (ns != NULL)
	{
		if (xmlStrEqual(ns->prefix, xmlName))
		{
			[self _removeNamespace:ns];
			break;
		}
		ns = ns->next;
	}
	
	// Note: The removeNamespace method properly handles the situation where the namespace is the default namespace
}

- (void)_addNamespace:(DDXMLNode *)namespace
{
	// NSXML version uses this same assertion
	DDXMLAssert([namespace _hasParent] == NO, @"Cannot add a namespace with a parent; detach or copy first");
	DDXMLAssert(IsXmlNsPtr(namespace->genericPtr), @"Not a namespace");
	
	xmlNodePtr node = (xmlNodePtr)genericPtr;
	xmlNsPtr ns = (xmlNsPtr)namespace->genericPtr;
	
	// Beware: [namespace prefix] does NOT return what you might expect.  Use [namespace name] instead.
	
	NSString *namespaceName = [namespace name];
	
	[self _removeNamespaceForPrefix:namespaceName];
	
	xmlNsPtr currentNs = node->nsDef;
	if (currentNs == NULL)
	{
		node->nsDef = ns;
	}
	else
	{
		while (currentNs->next != NULL)
		{
			currentNs = currentNs->next;
		}
		
		currentNs->next = ns;
	}
	
	// The namespace is now part of the xml tree heirarchy
	[namespace->owner release];
	namespace->owner = [self retain];
	
	if ([namespace isKindOfClass:[DDXMLNamespaceNode class]])
	{
		DDXMLNamespaceNode *ddNamespace = (DDXMLNamespaceNode *)namespace;
		
		// The xmlNs structure doesn't contain a reference to the parent, so we manage our own reference
		[ddNamespace _setNsParentPtr:node];
	}
	
	// Did we just add a default namespace
	if ([namespaceName isEqualToString:@""])
	{
		node->ns = ns;
		
		// Note: The removeNamespaceForPrefix method above properly handled removing any previous default namespace
	}
}

- (void)addNamespace:(DDXMLNode *)namespace
{
#if DDXML_DEBUG_MEMORY_ISSUES
	DDXMLNotZombieAssert();
#endif
	
	[self _addNamespace:namespace];
}

- (void)removeNamespaceForPrefix:(NSString *)name
{
#if DDXML_DEBUG_MEMORY_ISSUES
	DDXMLNotZombieAssert();
#endif
	
	[self _removeNamespaceForPrefix:name];
}

- (NSArray *)namespaces
{
#if DDXML_DEBUG_MEMORY_ISSUES
	DDXMLNotZombieAssert();
#endif
	
	NSMutableArray *result = [NSMutableArray array];
	
	xmlNsPtr ns = ((xmlNodePtr)genericPtr)->nsDef;
	while (ns != NULL)
	{
		[result addObject:[DDXMLNamespaceNode nodeWithNsPrimitive:ns nsParent:(xmlNodePtr)genericPtr owner:self]];
		
		ns = ns->next;
	}
	
	return result;
}

- (DDXMLNode *)namespaceForPrefix:(NSString *)prefix
{
#if DDXML_DEBUG_MEMORY_ISSUES
	DDXMLNotZombieAssert();
#endif
	
	// If the prefix is nil or the empty string, the user is requesting the default namespace
	
	if ([prefix length] == 0)
	{
		// Requesting the default namespace
		xmlNsPtr ns = ((xmlNodePtr)genericPtr)->ns;
		if (ns != NULL)
		{
			return [DDXMLNamespaceNode nodeWithNsPrimitive:ns nsParent:(xmlNodePtr)genericPtr owner:self];
		}
	}
	else
	{
		xmlNsPtr ns = ((xmlNodePtr)genericPtr)->nsDef;
		while (ns != NULL)
		{
			if (xmlStrEqual(ns->prefix, [prefix xmlChar]))
			{
				return [DDXMLNamespaceNode nodeWithNsPrimitive:ns nsParent:(xmlNodePtr)genericPtr owner:self];
			}
			ns = ns->next;
		}
	}
	
	return nil;
}

- (void)setNamespaces:(NSArray *)namespaces
{
#if DDXML_DEBUG_MEMORY_ISSUES
	DDXMLNotZombieAssert();
#endif
	
	[self _removeAllNamespaces];
	
	NSUInteger i;
	for (i = 0; i < [namespaces count]; i++)
	{
		DDXMLNode *namespace = [namespaces objectAtIndex:i];
		[self _addNamespace:namespace];
		
		// Note: The addNamespace method properly sets the freeOnDealloc ivar.
	}
}

/**
 * Recursively searches the given node for the given namespace
**/
- (DDXMLNode *)_recursiveResolveNamespaceForPrefix:(NSString *)prefix atNode:(xmlNodePtr)nodePtr
{
	// This is a private/internal method
	
	if (nodePtr == NULL) return nil;
	
	xmlNsPtr ns = nodePtr->nsDef;
	while (ns != NULL)
	{
		if (xmlStrEqual(ns->prefix, [prefix xmlChar]))
		{
			return [DDXMLNamespaceNode nodeWithNsPrimitive:ns nsParent:nodePtr owner:self];
		}
		ns = ns->next;
	}
	
	return [self _recursiveResolveNamespaceForPrefix:prefix atNode:nodePtr->parent];
}

/**
 * Returns the namespace node with the prefix matching the given qualified name.
 * Eg: You pass it "a:dog", it returns the namespace (defined in this node or parent nodes) that has the "a" prefix.
**/
- (DDXMLNode *)resolveNamespaceForName:(NSString *)name
{
#if DDXML_DEBUG_MEMORY_ISSUES
	DDXMLNotZombieAssert();
#endif
	
	// If the user passes nil or an empty string for name, they're looking for the default namespace.
	if ([name length] == 0)
	{
		return [self _recursiveResolveNamespaceForPrefix:nil atNode:(xmlNodePtr)genericPtr];
	}
	
	NSString *prefix = [[self class] prefixForName:name];
	
	if ([prefix length] > 0)
	{
		// Unfortunately we can't use xmlSearchNs because it returns an xmlNsPtr.
		// This gives us mostly what we want, except we also need to know the nsParent.
		// So we do the recursive search ourselves.
		
		return [self _recursiveResolveNamespaceForPrefix:prefix atNode:(xmlNodePtr)genericPtr];
	}
	
	return nil;
}

/**
 * Recursively searches the given node for a namespace with the given URI, and a set prefix.
**/
- (NSString *)_recursiveResolvePrefixForURI:(NSString *)uri atNode:(xmlNodePtr)nodePtr
{
	// This is a private/internal method
	
	if (nodePtr == NULL) return nil;
	
	xmlNsPtr ns = nodePtr->nsDef;
	while (ns != NULL)
	{
		if (xmlStrEqual(ns->href, [uri xmlChar]))
		{
			if (ns->prefix != NULL)
			{
				return [NSString stringWithUTF8String:((const char *)ns->prefix)];
			}
		}
		ns = ns->next;
	}
	
	return [self _recursiveResolvePrefixForURI:uri atNode:nodePtr->parent];
}

/**
 * Returns the prefix associated with the specified URI.
 * Returns a string that is the matching prefix or nil if it finds no matching prefix.
**/
- (NSString *)resolvePrefixForNamespaceURI:(NSString *)namespaceURI
{
#if DDXML_DEBUG_MEMORY_ISSUES
	DDXMLNotZombieAssert();
#endif
	
	// We can't use xmlSearchNsByHref because it will return xmlNsPtr's with NULL prefixes.
	// We're looking for a definitive prefix for the given URI.
	
	return [self _recursiveResolvePrefixForURI:namespaceURI atNode:(xmlNodePtr)genericPtr];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Children
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)addChild:(DDXMLNode *)child
{
#if DDXML_DEBUG_MEMORY_ISSUES
	DDXMLNotZombieAssert();
#endif
	
	// NSXML version uses these same assertions
	DDXMLAssert([child _hasParent] == NO, @"Cannot add a child that has a parent; detach or copy first");
	DDXMLAssert(IsXmlNodePtr(child->genericPtr),
	            @"Elements can only have text, elements, processing instructions, and comments as children");
	
	xmlAddChild((xmlNodePtr)genericPtr, (xmlNodePtr)child->genericPtr);
	
	// The node is now part of the xml tree heirarchy
	[child->owner release];
	child->owner = [self retain];
}

- (void)insertChild:(DDXMLNode *)child atIndex:(NSUInteger)index
{
#if DDXML_DEBUG_MEMORY_ISSUES
	DDXMLNotZombieAssert();
#endif
	
	// NSXML version uses these same assertions
	DDXMLAssert([child _hasParent] == NO, @"Cannot add a child that has a parent; detach or copy first");
	DDXMLAssert(IsXmlNodePtr(child->genericPtr),
	            @"Elements can only have text, elements, processing instructions, and comments as children");
	
	NSUInteger i = 0;
	
	xmlNodePtr childNodePtr = ((xmlNodePtr)genericPtr)->children;
	while (childNodePtr != NULL)
	{
		// Ignore all but element, comment, text, or processing instruction nodes
		if (IsXmlNodePtr(childNodePtr))
		{
			if (i == index)
			{
				xmlAddPrevSibling(childNodePtr, (xmlNodePtr)child->genericPtr);
				
				[child->owner release];
				child->owner = [self retain];
				
				return;
			}
			
			i++;
		}
		childNodePtr = childNodePtr->next;
	}
	
	if (i == index)
	{
		xmlAddChild((xmlNodePtr)genericPtr, (xmlNodePtr)child->genericPtr);
		
		[child->owner release];
		child->owner = [self retain];
		
		return;
	}
	
	// NSXML version uses this same assertion
	DDXMLAssert(NO, @"index (%u) beyond bounds (%u)", (unsigned)index, (unsigned)++i);
}

- (void)removeChildAtIndex:(NSUInteger)index
{
#if DDXML_DEBUG_MEMORY_ISSUES
	DDXMLNotZombieAssert();
#endif
	
	NSUInteger i = 0;
	
	xmlNodePtr child = ((xmlNodePtr)genericPtr)->children;
	while (child != NULL)
	{
		// Ignore all but element, comment, text, or processing instruction nodes
		if (IsXmlNodePtr(child))
		{
			if (i == index)
			{
				[DDXMLNode removeChild:child fromNode:(xmlNodePtr)genericPtr];
				return;
			}
			
			i++;
		}
		child = child->next;
	}
}

- (void)setChildren:(NSArray *)children
{
#if DDXML_DEBUG_MEMORY_ISSUES
	DDXMLNotZombieAssert();
#endif
	
	[DDXMLNode removeAllChildrenFromNode:(xmlNodePtr)genericPtr];
	
	NSUInteger i;
	for (i = 0; i < [children count]; i++)
	{
		DDXMLNode *child = [children objectAtIndex:i];
		[self addChild:child];
		
		// Note: The addChild method properly sets the freeOnDealloc ivar.
	}
}

@end
