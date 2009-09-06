#import "DDXMLElement.h"
#import "NSStringAdditions.h"
#import "DDXMLPrivate.h"


@implementation DDXMLElement

- (id)initWithName:(NSString *)name
{
	// Note: Make every guarantee that genericPtr is not null
	
	xmlNodePtr node = xmlNewNode(NULL, [name xmlChar]);
	if(node == NULL)
	{
		[self release];
		return nil;
	}
	
	return [self initWithCheckedPrimitive:(xmlKindPtr)node];
}

- (id)initWithName:(NSString *)name URI:(NSString *)URI
{
	// Note: Make every guarantee that genericPtr is not null
	
	xmlNodePtr node = xmlNewNode(NULL, [name xmlChar]);
	if(node == NULL)
	{
		[self release];
		return nil;
	}
	
	DDXMLElement *result = [self initWithCheckedPrimitive:(xmlKindPtr)node];
	[result setURI:URI];
	
	return result;
}

- (id)initWithName:(NSString *)name stringValue:(NSString *)string
{
	// Note: Make every guarantee that genericPtr is not null
	
	xmlNodePtr node = xmlNewNode(NULL, [name xmlChar]);
	if(node == NULL)
	{
		[self release];
		return nil;
	}
	
	DDXMLElement *result = [self initWithCheckedPrimitive:(xmlKindPtr)node];
	[result setStringValue:string];
	
	return result;
}

- (id)initWithXMLString:(NSString *)string error:(NSError **)error
{
	DDXMLDocument *doc = [[DDXMLDocument alloc] initWithXMLString:string options:0 error:error];
	if(doc == nil)
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

+ (id)nodeWithPrimitive:(xmlKindPtr)nodePtr
{
	if(nodePtr == NULL || nodePtr->type != XML_ELEMENT_NODE)
	{
		return nil;
	}
	
	xmlNodePtr node = (xmlNodePtr)nodePtr;
	if(node->_private == NULL)
		return [[[DDXMLElement alloc] initWithCheckedPrimitive:nodePtr] autorelease];
	else
		return [[((DDXMLElement *)(node->_private)) retain] autorelease];
}

- (id)initWithUncheckedPrimitive:(xmlKindPtr)nodePtr
{
	if(nodePtr == NULL || nodePtr->type != XML_ELEMENT_NODE)
	{
		[self release];
		return nil;
	}
	
	xmlNodePtr node = (xmlNodePtr)nodePtr;
	if(node->_private == NULL)
	{
		return [self initWithCheckedPrimitive:nodePtr];
	}
	else
	{
		[self release];
		return [((DDXMLElement *)(node->_private)) retain];
	}	
}

- (id)initWithCheckedPrimitive:(xmlKindPtr)nodePtr
{
	self = [super initWithCheckedPrimitive:nodePtr];
	return self;
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
	if(name == nil) return [NSArray array];
	
	// We need to check to see if name has a prefix.
	// If it does have a prefix, we need to figure out what the corresponding URI is for that prefix,
	// and then search for any elements that have the same name (including prefix) OR have the same URI.
	// Otherwise we loop through the children as usual and do a string compare on the name
	
	NSString *prefix = [[self class] prefixForName:name];
	if([prefix length] > 0)
	{
		xmlNodePtr node = (xmlNodePtr)genericPtr;
		xmlNsPtr ns = xmlSearchNs(node->doc, node, [prefix xmlChar]);
		if(ns != NULL)
		{
			NSString *uri = [NSString stringWithUTF8String:((const char *)ns->href)];
			return [self elementsWithName:name uri:uri];
		}
		
		// Note: We used xmlSearchNs instead of resolveNamespaceForName: - avoid creating wrapper objects when possible
	}
	
	return [self elementsWithName:name uri:nil];
}

- (NSArray *)elementsForLocalName:(NSString *)localName URI:(NSString *)URI
{
	if(localName == nil) return [NSArray array];
	
	// We need to figure out what the prefix is for this URI.
	// Then we search for elements that are named prefix:localName OR (named localName AND have the given URI).
	
	NSString *prefix = [self resolvePrefixForNamespaceURI:URI];
	if(prefix != nil)
	{
		NSString *name = [NSString stringWithFormat:@"%@:%@", prefix, localName];
		
		return [self elementsWithName:name uri:URI];
	}
	else
	{
		return [self elementsWithName:localName uri:URI];
	}
}

/**
 * Helper method elementsForName and elementsForLocalName:URI: so work isn't duplicated.
 * The name parameter is required, URI is optional.
**/
- (NSArray *)elementsWithName:(NSString *)name uri:(NSString *)uri
{
	// Supplied: name, !uri  : match: name
	// Supplied: p:name, uri : match: p:name || (name && uri)
	// Supplied: name, uri   : match: name && uri
	
	NSMutableArray *result = [NSMutableArray array];
	
	xmlNodePtr node = (xmlNodePtr)genericPtr;
	
	BOOL hasPrefix = [[[self class] prefixForName:name] length] > 0;
	NSString *localName = [[self class] localNameForName:name];
	
	xmlNodePtr child = node->children;
	while(child != NULL)
	{
		if(child->type == XML_ELEMENT_NODE)
		{
			BOOL match = NO;
			if(uri == nil)
			{
				match = xmlStrEqual(child->name, [name xmlChar]);
			}
			else
			{
				BOOL nameMatch = xmlStrEqual(child->name, [name xmlChar]);
				BOOL localNameMatch = xmlStrEqual(child->name, [localName xmlChar]);
				
				BOOL uriMatch = NO;
				if(child->ns != NULL)
				{
					uriMatch = xmlStrEqual(child->ns->href, [uri xmlChar]);
				}
				
				if(hasPrefix)
					match = nameMatch || (localNameMatch && uriMatch);
				else
					match = nameMatch && uriMatch;
			}
			
			if(match)
			{
				[result addObject:[DDXMLElement nodeWithPrimitive:(xmlKindPtr)child]];
			}
		}
		
		child = child->next;
	}
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Attributes
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)addAttribute:(DDXMLNode *)attribute
{
	// NSXML version uses this same assertion
	DDCheck([attribute hasParent] == NO, @"Cannot add an attribute with a parent; detach or copy first");
	DDCheck([attribute isXmlAttrPtr], @"Not an attribute");
	
	// xmlNodePtr xmlAddChild(xmlNodePtr parent, xmlNodePtr cur)
	// Add a new node to @parent, at the end of the child (or property) list merging
	// adjacent TEXT nodes (in which case @cur is freed). If the new node is ATTRIBUTE, it is added
	// into properties instead of children. If there is an attribute with equal name, it is first destroyed.
	
	[self removeAttributeForName:[attribute name]];
	
	xmlAddChild((xmlNodePtr)genericPtr, (xmlNodePtr)attribute->genericPtr);
}

- (void)removeAttribute:(xmlAttrPtr)attr
{
	[[self class] removeAttribute:attr fromNode:(xmlNodePtr)genericPtr];
}

- (void)removeAllAttributes
{
	[[self class] removeAllAttributesFromNode:(xmlNodePtr)genericPtr];
}

- (void)removeAttributeForName:(NSString *)name
{
	// If we use xmlUnsetProp, then the attribute will be automatically freed.
	// We don't want this unless no other wrapper objects have a reference to the property.
	
	xmlAttrPtr attr = ((xmlNodePtr)genericPtr)->properties;
	while(attr != NULL)
	{
		if(xmlStrEqual(attr->name, [name xmlChar]))
		{
			[self removeAttribute:attr];
			return;
		}
		attr = attr->next;
	}
}

- (NSArray *)attributes
{
	NSMutableArray *result = [NSMutableArray array];
	
	xmlAttrPtr attr = ((xmlNodePtr)genericPtr)->properties;
	while(attr != NULL)
	{
		[result addObject:[DDXMLNode nodeWithPrimitive:(xmlKindPtr)attr]];
		
		attr = attr->next;
	}
	
	return result;
}

- (DDXMLNode *)attributeForName:(NSString *)name
{
	xmlAttrPtr attr = ((xmlNodePtr)genericPtr)->properties;
	while(attr != NULL)
	{
		if(xmlStrEqual([name xmlChar], attr->name))
		{
			return [DDXMLNode nodeWithPrimitive:(xmlKindPtr)attr];
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
	[self removeAllAttributes];
	
	NSUInteger i;
	for(i = 0; i < [attributes count]; i++)
	{
		DDXMLNode *attribute = [attributes objectAtIndex:i];
		[self addAttribute:attribute];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Namespaces
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)addNamespace:(DDXMLNode *)namespace
{
	// NSXML version uses this same assertion
	DDCheck([namespace hasParent] == NO, @"Cannot add a namespace with a parent; detach or copy first");
	DDCheck([namespace isXmlNsPtr], @"Not a namespace");
	
	// Beware: [namespace prefix] does NOT return what you might expect.  Use [namespace name] instead.
	
	[self removeNamespaceForPrefix:[namespace name]];
	
	xmlNsPtr currentNs = ((xmlNodePtr)genericPtr)->nsDef;
	if(currentNs == NULL)
	{
		((xmlNodePtr)genericPtr)->nsDef = (xmlNsPtr)namespace->genericPtr;
	}
	else
	{
		while(currentNs != NULL)
		{
			if(currentNs->next == NULL)
			{
				currentNs->next = (xmlNsPtr)namespace->genericPtr;
				break; // Yes this break is needed
			}
			currentNs = currentNs->next;
		}
	}
	
	// The xmlNs structure doesn't contain a reference to the parent, so we manage our own reference
	namespace->nsParentPtr = (xmlNodePtr)genericPtr;
	
	// Did we just add a default namespace
	if([[namespace name] isEqualToString:@""])
	{
		((xmlNodePtr)genericPtr)->ns = (xmlNsPtr)namespace->genericPtr;
		
		// Note: The removeNamespaceForPrefix method above properly handled removing any previous default namespace
	}
}

- (void)removeNamespace:(xmlNsPtr)ns
{
	[[self class] removeNamespace:ns fromNode:(xmlNodePtr)genericPtr];
}

- (void)removeAllNamespaces
{
	[[self class] removeAllNamespacesFromNode:(xmlNodePtr)genericPtr];
}

- (void)removeNamespaceForPrefix:(NSString *)name
{
	// If name is nil or the empty string, the user is wishing to remove the default namespace
	const xmlChar *xmlName = [name length] > 0 ? [name xmlChar] : NULL;
	
	xmlNsPtr ns = ((xmlNodePtr)genericPtr)->nsDef;
	while(ns != NULL)
	{
		if(xmlStrEqual(ns->prefix, xmlName))
		{
			[self removeNamespace:ns];
			break;
		}
		ns = ns->next;
	}
	
	// Note: The removeNamespace method properly handles the situation where the namespace is the default namespace
}

- (NSArray *)namespaces
{
	NSMutableArray *result = [NSMutableArray array];
	
	xmlNsPtr ns = ((xmlNodePtr)genericPtr)->nsDef;
	while(ns != NULL)
	{
		[result addObject:[DDXMLNode nodeWithPrimitive:(xmlKindPtr)ns nsParent:(xmlNodePtr)genericPtr]];
		
		ns = ns->next;
	}
	
	return result;
}

- (DDXMLNode *)namespaceForPrefix:(NSString *)prefix
{
	// If the prefix is nil or the empty string, the user is requesting the default namespace
	
	if([prefix length] == 0)
	{
		// Requesting the default namespace
		xmlNsPtr ns = ((xmlNodePtr)genericPtr)->ns;
		if(ns != NULL)
		{
			return [DDXMLNode nodeWithPrimitive:(xmlKindPtr)ns nsParent:(xmlNodePtr)genericPtr];
		}
	}
	else
	{
		xmlNsPtr ns = ((xmlNodePtr)genericPtr)->nsDef;
		while(ns != NULL)
		{
			if(xmlStrEqual(ns->prefix, [prefix xmlChar]))
			{
				return [DDXMLNode nodeWithPrimitive:(xmlKindPtr)ns nsParent:(xmlNodePtr)genericPtr];
			}
			ns = ns->next;
		}
	}
	
	return nil;
}

- (void)setNamespaces:(NSArray *)namespaces
{
	[self removeAllNamespaces];
	
	NSUInteger i;
	for(i = 0; i < [namespaces count]; i++)
	{
		DDXMLNode *namespace = [namespaces objectAtIndex:i];
		[self addNamespace:namespace];
	}
}

/**
 * Recursively searches the given node for the given namespace
**/
+ (DDXMLNode *)resolveNamespaceForPrefix:(NSString *)prefix atNode:(xmlNodePtr)nodePtr
{
	if(nodePtr == NULL) return nil;
	
	xmlNsPtr ns = nodePtr->nsDef;
	while(ns != NULL)
	{
		if(xmlStrEqual(ns->prefix, [prefix xmlChar]))
		{
			return [DDXMLNode nodeWithPrimitive:(xmlKindPtr)ns nsParent:nodePtr];
		}
		ns = ns->next;
	}
	
	return [self resolveNamespaceForPrefix:prefix atNode:nodePtr->parent];
}

/**
 * Returns the namespace node with the prefix matching the given qualified name.
 * Eg: You pass it "a:dog", it returns the namespace (defined in this node or parent nodes) that has the "a" prefix.
**/
- (DDXMLNode *)resolveNamespaceForName:(NSString *)name
{
	// If the user passes nil or an empty string for name, they're looking for the default namespace.
	if([name length] == 0)
	{
		return [[self class] resolveNamespaceForPrefix:nil atNode:(xmlNodePtr)genericPtr];
	}
	
	NSString *prefix = [[self class] prefixForName:name];
	
	if([prefix length] > 0)
	{
		// Unfortunately we can't use xmlSearchNs because it returns an xmlNsPtr.
		// This gives us mostly what we want, except we also need to know the nsParent.
		// So we do the recursive search ourselves.
		
		return [[self class] resolveNamespaceForPrefix:prefix atNode:(xmlNodePtr)genericPtr];
	}
	
	return nil;
}

/**
 * Recursively searches the given node for a namespace with the given URI, and a set prefix.
**/
+ (NSString *)resolvePrefixForURI:(NSString *)uri atNode:(xmlNodePtr)nodePtr
{
	if(nodePtr == NULL) return nil;
	
	xmlNsPtr ns = nodePtr->nsDef;
	while(ns != NULL)
	{
		if(xmlStrEqual(ns->href, [uri xmlChar]))
		{
			if(ns->prefix != NULL)
			{
				return [NSString stringWithUTF8String:((const char *)ns->prefix)];
			}
		}
		ns = ns->next;
	}
	
	return [self resolvePrefixForURI:uri atNode:nodePtr->parent];
}

/**
 * Returns the prefix associated with the specified URI.
 * Returns a string that is the matching prefix or nil if it finds no matching prefix.
**/
- (NSString *)resolvePrefixForNamespaceURI:(NSString *)namespaceURI
{
	// We can't use xmlSearchNsByHref because it will return xmlNsPtr's with NULL prefixes.
	// We're looking for a definitive prefix for the given URI.
	
	return [[self class] resolvePrefixForURI:namespaceURI atNode:(xmlNodePtr)genericPtr];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Children
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)removeChild:(xmlNodePtr)child
{
	[[self class] removeChild:child fromNode:(xmlNodePtr)genericPtr];
}

- (void)removeAllChildren
{
	[[self class] removeAllChildrenFromNode:(xmlNodePtr)genericPtr];
}

- (void)removeChildAtIndex:(NSUInteger)index
{
	NSUInteger i = 0;
	
	xmlNodePtr child = ((xmlNodePtr)genericPtr)->children;
	while(child != NULL)
	{
		// Ignore all but element, comment, text, or processing instruction nodes
		if([[self class] isXmlNodePtr:(xmlKindPtr)child])
		{
			if(i == index)
			{
				[self removeChild:child];
				return;
			}
			
			i++;
		}
		child = child->next;
	}
}

- (void)addChild:(DDXMLNode *)child
{
	// NSXML version uses these same assertions
	DDCheck([child hasParent] == NO, @"Cannot add a child that has a parent; detach or copy first");
	DDCheck([child isXmlNodePtr], @"Elements can only have text, elements, processing instructions, and comments as children");
	
	xmlAddChild((xmlNodePtr)genericPtr, (xmlNodePtr)child->genericPtr);
}

- (void)insertChild:(DDXMLNode *)child atIndex:(NSUInteger)index
{
	// NSXML version uses these same assertions
	DDCheck([child hasParent] == NO, @"Cannot add a child that has a parent; detach or copy first");
	DDCheck([child isXmlNodePtr], @"Elements can only have text, elements, processing instructions, and comments as children");
	
	NSUInteger i = 0;
	
	xmlNodePtr childNodePtr = ((xmlNodePtr)genericPtr)->children;
	while(childNodePtr != NULL)
	{
		// Ignore all but element, comment, text, or processing instruction nodes
		if([[self class] isXmlNodePtr:(xmlKindPtr)childNodePtr])
		{
			if(i == index)
			{
				xmlAddPrevSibling(childNodePtr, (xmlNodePtr)child->genericPtr);
				return;
			}
			
			i++;
		}
		childNodePtr = childNodePtr->next;
	}
	
	if(i == index)
	{
		xmlAddChild((xmlNodePtr)genericPtr, (xmlNodePtr)child->genericPtr);
		return;
	}
	
	// NSXML version uses this same assertion
	DDCheck(NO, @"index (%u) beyond bounds (%u)", (unsigned)index, (unsigned)++i);
}

- (void)setChildren:(NSArray *)children
{
	[self removeAllChildren];
	
	NSUInteger i;
	for(i = 0; i < [children count]; i++)
	{
		DDXMLNode *child = [children objectAtIndex:i];
		[self addChild:child];
	}
}

@end
