#import "DDXMLPrivate.h"
#import "NSString+DDXML.h"


@implementation DDXMLDocument

/**
 * Returns a DDXML wrapper object for the given primitive node.
 * The given node MUST be non-NULL and of the proper type.
**/
+ (id)nodeWithDocPrimitive:(xmlDocPtr)doc freeOnDealloc:(BOOL)flag
{
	return [[[DDXMLDocument alloc] initWithDocPrimitive:doc freeOnDealloc:flag] autorelease];
}

- (id)initWithDocPrimitive:(xmlDocPtr)doc freeOnDealloc:(BOOL)flag
{
	self = [super initWithPrimitive:(xmlKindPtr)doc freeOnDealloc:flag];
	return self;
}

+ (id)nodeWithPrimitive:(xmlKindPtr)kindPtr freeOnDealloc:(BOOL)flag
{
	// Promote initializers which use proper parameter types to enable compiler to catch more mistakes
	NSAssert(NO, @"Use nodeWithDocPrimitive:freeOnDealloc:");
	
	return nil;
}

- (id)initWithPrimitive:(xmlKindPtr)kindPtr freeOnDealloc:(BOOL)flag
{
	// Promote initializers which use proper parameter types to enable compiler to catch more mistakes.
	NSAssert(NO, @"Use initWithDocPrimitive:freeOnDealloc:");
	
	[self release];
	return nil;
}

/**
 * Initializes and returns a DDXMLDocument object created from an NSData object.
 * 
 * Returns an initialized DDXMLDocument object, or nil if initialization fails
 * because of parsing errors or other reasons.
**/
- (id)initWithXMLString:(NSString *)string options:(NSUInteger)mask error:(NSError **)error
{
	return [self initWithData:[string dataUsingEncoding:NSUTF8StringEncoding]
	                  options:mask
	                    error:error];
}

/**
 * Initializes and returns a DDXMLDocument object created from an NSData object.
 * 
 * Returns an initialized DDXMLDocument object, or nil if initialization fails
 * because of parsing errors or other reasons.
**/
- (id)initWithData:(NSData *)data options:(NSUInteger)mask error:(NSError **)error
{
	if (data == nil || [data length] == 0)
	{
		if (error) *error = [NSError errorWithDomain:@"DDXMLErrorDomain" code:0 userInfo:nil];
		
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
	if (doc == NULL)
	{
		if (error) *error = [NSError errorWithDomain:@"DDXMLErrorDomain" code:1 userInfo:nil];
		
		[self release];
		return nil;
	}
	
	return [self initWithDocPrimitive:doc freeOnDealloc:YES];
}

/**
 * Returns the root element of the receiver.
**/
- (DDXMLElement *)rootElement
{
#if DDXML_DEBUG_MEMORY_ISSUES
	DDXMLNotZombieAssert();
#endif
	
	xmlDocPtr doc = (xmlDocPtr)genericPtr;
	
	// doc->children is a list containing possibly comments, DTDs, etc...
	
	xmlNodePtr rootNode = xmlDocGetRootElement(doc);
	
	if (rootNode != NULL)
		return [DDXMLElement nodeWithElementPrimitive:rootNode freeOnDealloc:NO];
	else
		return nil;
}

- (NSData *)XMLData
{
	// Zombie test occurs in XMLString
	
	return [[self XMLString] dataUsingEncoding:NSUTF8StringEncoding];
}

- (NSData *)XMLDataWithOptions:(NSUInteger)options
{
	// Zombie test occurs in XMLString
	
	return [[self XMLStringWithOptions:options] dataUsingEncoding:NSUTF8StringEncoding];
}

@end
