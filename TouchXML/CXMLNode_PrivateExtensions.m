//
//  CXMLNode_PrivateExtensions.m
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

#import "CXMLNode_PrivateExtensions.h"

#import "CXMLElement.h"
#import "CXMLDocument_PrivateExtensions.h"

@implementation CXMLNode (CXMLNode_PrivateExtensions)

- (id)initWithLibXMLNode:(xmlNodePtr)inLibXMLNode;
{
if ((self = [super init]) != NULL)
	{
	_node = inLibXMLNode;
	}
return(self);
}

+ (id)nodeWithLibXMLNode:(xmlNodePtr)inLibXMLNode
{
// TODO more checking.
if (inLibXMLNode->_private)
	return(inLibXMLNode->_private);

Class theClass = [CXMLNode class];
switch (inLibXMLNode->type)
	{
	case XML_ELEMENT_NODE:
		theClass = [CXMLElement class];
		break;
	case XML_ATTRIBUTE_NODE:
	case XML_TEXT_NODE:
	case XML_CDATA_SECTION_NODE:
	case XML_COMMENT_NODE:
		break;
	default:
		NSAssert1(NO, @"TODO Unhandled type (%d).", inLibXMLNode->type);
		return(NULL);
	}

CXMLNode *theNode = [[[theClass alloc] initWithLibXMLNode:inLibXMLNode] autorelease];


CXMLDocument *theXMLDocument = inLibXMLNode->doc->_private;
NSAssert(theXMLDocument != NULL, @"TODO");
NSAssert([theXMLDocument isKindOfClass:[CXMLDocument class]] == YES, @"TODO");

[[theXMLDocument nodePool] addObject:theNode];

theNode->_node->_private = theNode;
return(theNode);
}

@end
