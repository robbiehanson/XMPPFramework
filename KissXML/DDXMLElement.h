#import <Foundation/Foundation.h>
#import "DDXMLNode.h"


@interface DDXMLElement : DDXMLNode
{
}

- (id)initWithName:(NSString *)name;
- (id)initWithName:(NSString *)name URI:(NSString *)URI;
- (id)initWithName:(NSString *)name stringValue:(NSString *)string;
- (id)initWithXMLString:(NSString *)string error:(NSError **)error;

#pragma mark --- Elements by name ---

- (NSArray *)elementsForName:(NSString *)name;
- (NSArray *)elementsForLocalName:(NSString *)localName URI:(NSString *)URI;

#pragma mark --- Attributes ---

- (void)addAttribute:(DDXMLNode *)attribute;
- (void)removeAttributeForName:(NSString *)name;
- (void)setAttributes:(NSArray *)attributes;
//- (void)setAttributesAsDictionary:(NSDictionary *)attributes;
- (NSArray *)attributes;
- (DDXMLNode *)attributeForName:(NSString *)name;
//- (DDXMLNode *)attributeForLocalName:(NSString *)localName URI:(NSString *)URI;

#pragma mark --- Namespaces ---

- (void)addNamespace:(DDXMLNode *)aNamespace;
- (void)removeNamespaceForPrefix:(NSString *)name;
- (void)setNamespaces:(NSArray *)namespaces;
- (NSArray *)namespaces;
- (DDXMLNode *)namespaceForPrefix:(NSString *)prefix;
- (DDXMLNode *)resolveNamespaceForName:(NSString *)name;
- (NSString *)resolvePrefixForNamespaceURI:(NSString *)namespaceURI;

#pragma mark --- Children ---

- (void)insertChild:(DDXMLNode *)child atIndex:(NSUInteger)index;
//- (void)insertChildren:(NSArray *)children atIndex:(NSUInteger)index;
- (void)removeChildAtIndex:(NSUInteger)index;
- (void)setChildren:(NSArray *)children;
- (void)addChild:(DDXMLNode *)child;
//- (void)replaceChildAtIndex:(NSUInteger)index withNode:(DDXMLNode *)node;
//- (void)normalizeAdjacentTextNodesPreservingCDATA:(BOOL)preserve;

@end
