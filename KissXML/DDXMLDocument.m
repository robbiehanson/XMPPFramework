#import "DDXMLDocument.h"
#import "NSStringAdditions.h"
#import "DDXMLPrivate.h"


@implementation DDXMLDocument

void MyErrorHandler(void * userData, xmlErrorPtr error)
{
	// Here we could extract the information from xmlError struct
}

+ (void)initialize
{
	static BOOL initialized = NO;
	if(!initialized)
	{
		// Redirect error output to our own function (don't clog up the console)
		initGenericErrorDefaultFunc(NULL);
		xmlSetStructuredErrorFunc(NULL, MyErrorHandler);
		
		initialized = YES;
	}
}

+ (id)nodeWithPrimitive:(xmlKindPtr)nodePtr
{
	return [[[DDXMLDocument alloc] initWithPrimitive:nodePtr] autorelease];
}

- (id)initWithPrimitive:(xmlKindPtr)nodePtr
{
	if(nodePtr == NULL || nodePtr->type != XML_DOCUMENT_NODE)
	{
		[super dealloc];
		return nil;
	}
	
	self = [super initWithPrimitive:nodePtr];
	return self;
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
		
		[super dealloc];
		return nil;
	}
	
	xmlDocPtr doc = xmlParseMemory([data bytes], [data length]);
	if(doc == NULL)
	{
		if(error) *error = [NSError errorWithDomain:@"DDXMLErrorDomain" code:1 userInfo:nil];
		
		[super dealloc];
		return nil;
	}
	
	return [self initWithPrimitive:(xmlKindPtr)doc];
}

/**
 * Returns the root element of the receiver.
**/
- (DDXMLElement *)rootElement
{
	xmlDocPtr docPtr = (xmlDocPtr)genericPtr;
	
	if(docPtr->children == NULL)
		return nil;
	else
		return [DDXMLElement nodeWithPrimitive:(xmlKindPtr)(docPtr->children)];
}

@end
