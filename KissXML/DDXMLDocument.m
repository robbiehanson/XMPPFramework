#import "DDXMLDocument.h"
#import "NSStringAdditions.h"
#import "DDXMLPrivate.h"


@implementation DDXMLDocument

+ (id)nodeWithPrimitive:(xmlKindPtr)nodePtr
{
	if(nodePtr == NULL || nodePtr->type != XML_DOCUMENT_NODE)
	{
		return nil;
	}
	
	xmlDocPtr doc = (xmlDocPtr)nodePtr;
	if(doc->_private == NULL)
		return [[[DDXMLDocument alloc] initWithCheckedPrimitive:nodePtr] autorelease];
	else
		return [[((DDXMLDocument *)(doc->_private)) retain] autorelease];
}

- (id)initWithUncheckedPrimitive:(xmlKindPtr)nodePtr
{
	if(nodePtr == NULL || nodePtr->type != XML_DOCUMENT_NODE)
	{
		[self release];
		return nil;
	}
	
	xmlDocPtr doc = (xmlDocPtr)nodePtr;
	if(doc->_private == NULL)
	{
		return [self initWithCheckedPrimitive:nodePtr];
	}
	else
	{
		[self release];
		return [((DDXMLDocument *)(doc->_private)) retain];
	}
}

- (id)initWithCheckedPrimitive:(xmlKindPtr)nodePtr
{
	self = [super initWithCheckedPrimitive:nodePtr];
	return self;
}

/**
 * Initializes and returns a DDXMLDocument object created from an NSData object.
 * 
 * Returns an initialized DDXMLDocument object, or nil if initialization fails
 * because of parsing errors or other reasons.
**/
- (id)initWithXMLString:(NSString *)string options:(NSUInteger)mask error:(NSError **)error
{
	return [self initWithData:[string dataUsingEncoding:NSUTF8StringEncoding] options:mask error:error];
}

/**
 * Initializes and returns a DDXMLDocument object created from an NSData object.
 * 
 * Returns an initialized DDXMLDocument object, or nil if initialization fails
 * because of parsing errors or other reasons.
**/
- (id)initWithData:(NSData *)data options:(NSUInteger)mask error:(NSError **)error
{
	if(data == nil || [data length] == 0)
	{
		if(error) *error = [NSError errorWithDomain:@"DDXMLErrorDomain" code:0 userInfo:nil];
		
		[self release];
		return nil;
	}
	
	// Even though xmlKeepBlanksDefault(0) is called in DDXMLNode's initialize method,
	// it has been documented that this call seems to get reset on the iPhone:
	// http://code.google.com/p/kissxml/issues/detail?id=8
	// 
	// Therefore, we call it again here just to be safe.
	xmlKeepBlanksDefault(0);
	
	xmlDocPtr doc = xmlParseMemory([data bytes], [data length]);
	if(doc == NULL)
	{
		if(error) *error = [NSError errorWithDomain:@"DDXMLErrorDomain" code:1 userInfo:nil];
		
		[self release];
		return nil;
	}
	
	return [self initWithCheckedPrimitive:(xmlKindPtr)doc];
}

/**
 * Returns the root element of the receiver.
**/
- (DDXMLElement *)rootElement
{
	xmlDocPtr doc = (xmlDocPtr)genericPtr;
	
	// doc->children is a list containing possibly comments, DTDs, etc...
	
	xmlNodePtr rootNode = xmlDocGetRootElement(doc);
	
	if(rootNode != NULL)
		return [DDXMLElement nodeWithPrimitive:(xmlKindPtr)(rootNode)];
	else
		return nil;
}

- (NSData *)XMLData
{
	return [[self XMLString] dataUsingEncoding:NSUTF8StringEncoding];
}

- (NSData *)XMLDataWithOptions:(NSUInteger)options
{
	return [[self XMLStringWithOptions:options] dataUsingEncoding:NSUTF8StringEncoding];
}

@end
