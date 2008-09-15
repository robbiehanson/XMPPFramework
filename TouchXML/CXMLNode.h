//
//  CXMLNode.h
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

#import <Foundation/Foundation.h>

#include <libxml/tree.h>

typedef enum {
	CXMLInvalidKind = 0,
	CXMLElementKind = XML_ELEMENT_NODE,
	CXMLAttributeKind = XML_ATTRIBUTE_NODE,
	CXMLTextKind = XML_TEXT_NODE,
	CXMLProcessingInstructionKind = XML_PI_NODE,
	CXMLCommentKind = XML_COMMENT_NODE,
	CXMLNotationDeclarationKind = XML_NOTATION_NODE,
	CXMLDTDKind = XML_DTD_NODE,
	CXMLElementDeclarationKind =  XML_ELEMENT_DECL,
	CXMLAttributeDeclarationKind =  XML_ATTRIBUTE_DECL,
	CXMLEntityDeclarationKind = XML_ENTITY_DECL,
	CXMLNamespaceKind = XML_NAMESPACE_DECL,
} CXMLNodeKind;

@class CXMLDocument;

// NSXMLNode
@interface CXMLNode : NSObject {
	xmlNodePtr _node;
}

- (CXMLNodeKind)kind;
- (NSString *)name;
- (NSString *)stringValue;
- (NSUInteger)index;
- (NSUInteger)level;
- (CXMLDocument *)rootDocument;
- (CXMLNode *)parent;
- (NSUInteger)childCount;
- (NSArray *)children;
- (CXMLNode *)childAtIndex:(NSUInteger)index;
- (CXMLNode *)previousSibling;
- (CXMLNode *)nextSibling;
//- (CXMLNode *)previousNode;
//- (CXMLNode *)nextNode;
//- (NSString *)XPath;
//- (NSString *)localName;
//- (NSString *)prefix;
//- (NSString *)URI;
//+ (NSString *)localNameForName:(NSString *)name;
//+ (NSString *)prefixForName:(NSString *)name;
//+ (CXMLNode *)predefinedNamespaceForPrefix:(NSString *)name;
- (NSString *)description;
- (NSString *)XMLString;
- (NSString *)XMLStringWithOptions:(NSUInteger)options;
//- (NSString *)canonicalXMLStringPreservingComments:(BOOL)comments;
- (NSArray *)nodesForXPath:(NSString *)xpath error:(NSError **)error;

- (NSString*)_XMLStringWithOptions:(NSUInteger)options appendingToString:(NSMutableString*)str;
@end
