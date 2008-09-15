//
//  CXMLNode_XPathExtensions.m
//  TouchXML
//
//  Created by Jonathan Wight on 04/01/08.
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

#import "CXMLNode_XPathExtensions.h"

#import "CXMLDocument.h"
#import "CXMLNode_PrivateExtensions.h"

#include <libxml/xpath.h>
#include <libxml/xpathInternals.h>

@implementation CXMLNode (CXMLNode_NamespaceExtensions)

- (NSArray *)nodesForXPath:(NSString *)xpath namespaceMappings:(NSDictionary *)inNamespaceMappings error:(NSError **)error;
{
NSAssert(_node != NULL, @"TODO");

NSArray *theResult = NULL;

CXMLNode *theRootDocument = [self rootDocument];
xmlXPathContextPtr theXPathContext = xmlXPathNewContext((xmlDocPtr)theRootDocument->_node);
theXPathContext->node = _node;

for (NSString *thePrefix in inNamespaceMappings)
	{
	xmlXPathRegisterNs(theXPathContext, (xmlChar *)[thePrefix UTF8String], (xmlChar *)[[inNamespaceMappings objectForKey:thePrefix] UTF8String]);
	}

// TODO considering putting xmlChar <-> UTF8 into a NSString category
xmlXPathObjectPtr theXPathObject = xmlXPathEvalExpression((const xmlChar *)[xpath UTF8String], theXPathContext);
if (xmlXPathNodeSetIsEmpty(theXPathObject->nodesetval))
	theResult = [NSArray array]; // TODO better to return NULL?
else
	{
	NSMutableArray *theArray = [NSMutableArray array];
	int N;
	for (N = 0; N < theXPathObject->nodesetval->nodeNr; N++)
		{
		xmlNodePtr theNode = theXPathObject->nodesetval->nodeTab[N];
		[theArray addObject:[CXMLNode nodeWithLibXMLNode:theNode]];
		}
		
	theResult = theArray;
	}
	
xmlXPathFreeObject(theXPathObject);

xmlXPathFreeContext(theXPathContext);
return(theResult);
}

@end
