//
//  CXMLDocument
//  TouchXML
//
//  Created by Jonathan Wight on 03/07/08.
//  Copyright (c) 2008 Jonathan Wight
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.
//

#import "CXMLDocument.h"

#include <libxml/parser.h>
#include <libxml/HTMLparser.h>
#include <libxml/HTMLtree.h>

#import "CXMLNode_PrivateExtensions.h"
#import "CXMLElement.h"

@implementation CXMLDocument

static void htmlparser_error(void *ctx, const char *msg, ...)
{
	va_list args;
	va_start(args, msg);
	va_end(args);
}

static void htmlparser_warning(void *ctx, const char *msg, ...)
{
	va_list args;
	va_start(args, msg);
	va_end(args);
}

- (id)initWithXMLString:(NSString *)inString options:(NSUInteger)inOptions error:(NSError **)outError
{
if ((self = [super init]) != NULL)
	{
	if (outError)
		*outError = NULL;
	
	xmlDocPtr theDoc;
	if ( inOptions & CXMLDocumentTidyHTML )
		{
		const char *htmlString = (const char*) [inString UTF8String];
		int length = xmlStrlen( (const xmlChar*)htmlString );
		htmlParserCtxtPtr ctx = htmlCreateMemoryParserCtxt(htmlString, length);

		if (! ctx ) {
			return 0;
		}	
		
		ctx->vctxt.error = htmlparser_error;
		ctx->vctxt.warning = htmlparser_warning;
		if (ctx->sax != NULL)
			{
			ctx->sax->error = htmlparser_error;
			ctx->sax->warning = htmlparser_warning;
			}
		htmlParseDocument(ctx);
		theDoc = ctx->myDoc;
		htmlFreeParserCtxt(ctx);
		}
	else
		{
		theDoc = xmlParseDoc((xmlChar *)[inString UTF8String]);
		}


	if (theDoc != NULL)
		{
		_node = (xmlNodePtr)theDoc;
		NSAssert(_node->_private == NULL, @"TODO");
		_node->_private = self; // Note. NOT retained (TODO think more about _private usage)
		}
	else
		{
		if (outError)
			*outError = [NSError errorWithDomain:@"CXMLErrorDomain" code:1 userInfo:NULL];
		self = NULL;
		}
	}
return(self);
}

- (id)initWithContentsOfURL:(NSURL *)inURL options:(NSUInteger)inOptions error:(NSError **)outError
{
if (outError)
	*outError = NULL;

NSData *theData = [NSData dataWithContentsOfURL:inURL options:NSUncachedRead error:outError];
if (theData)
	{
	self = [self initWithData:theData options:inOptions error:outError];
	}
else
	{
	
	self = NULL;
	}
	
return(self);
}

- (id)initWithData:(NSData *)inData options:(NSUInteger)inOptions error:(NSError **)outError
{
if ((self = [super init]) != NULL)
	{
	xmlDocPtr theDoc = NULL;

	if (inData && inData.length > 0)
		{
		theDoc = xmlParseMemory([inData bytes], [inData length]);
		}
	
	if (theDoc != NULL)
		{
		_node = (xmlNodePtr)theDoc;
		_node->_private = self; // Note. NOT retained (TODO think more about _private usage)
		}
	else
		{
		if (outError)
			*outError = [NSError errorWithDomain:@"CXMLErrorDomain" code:1 userInfo:NULL];
		self = NULL;
		}
	}
return(self);
}

- (void)dealloc
{
xmlFreeDoc((xmlDocPtr)_node);
_node = NULL;
//

[nodePool release];
nodePool = NULL;
//
[super dealloc];
}

//- (NSString *)characterEncoding;
//- (NSString *)version;
//- (BOOL)isStandalone;
//- (CXMLDocumentContentKind)documentContentKind;
//- (NSString *)MIMEType;
//- (CXMLDTD *)DTD;

- (CXMLElement *)rootElement
{
xmlNodePtr theLibXMLNode = xmlDocGetRootElement((xmlDocPtr)_node);
	
return([CXMLNode nodeWithLibXMLNode:theLibXMLNode]);
}

//- (NSData *)XMLData;
//- (NSData *)XMLDataWithOptions:(NSUInteger)options;

//- (id)objectByApplyingXSLT:(NSData *)xslt arguments:(NSDictionary *)arguments error:(NSError **)error;
//- (id)objectByApplyingXSLTString:(NSString *)xslt arguments:(NSDictionary *)arguments error:(NSError **)error;
//- (id)objectByApplyingXSLTAtURL:(NSURL *)xsltURL arguments:(NSDictionary *)argument error:(NSError **)error;
- (id)XMLStringWithOptions:(NSUInteger)options
{
id root = [self rootElement];
NSMutableString* xmlString = [NSMutableString string];
[root _XMLStringWithOptions:options appendingToString:xmlString];
return xmlString;
}

- (NSString *)description
{
	NSAssert(_node != NULL, @"TODO");

	NSMutableString *result = [NSMutableString stringWithFormat:@"<%@ %p [%p]> ", NSStringFromClass([self class]), self, self->_node];
	xmlChar *xmlbuff;
	int buffersize;

	xmlDocDumpFormatMemory((xmlDocPtr)(self->_node), &xmlbuff, &buffersize, 1);
	NSString *dump = [[[NSString alloc] initWithBytes:xmlbuff length:buffersize encoding:NSUTF8StringEncoding] autorelease];
	xmlFree(xmlbuff);
							   
	[result appendString:dump];
	return result;
}

@end
