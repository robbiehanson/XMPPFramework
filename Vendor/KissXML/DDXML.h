#if TARGET_OS_IPHONE

#import "DDXMLNode.h"
#import "DDXMLElement.h"
#import "DDXMLDocument.h"

#ifndef NSXMLNode
  #define NSXMLNode DDXMLNode
#endif
#ifndef NSXMLElement
  #define NSXMLElement DDXMLElement
#endif
#ifndef NSXMLDocument
  #define NSXMLDocument DDXMLDocument
#endif

#ifndef NSXMLInvalidKind
  #define NSXMLInvalidKind DDXMLInvalidKind
#endif
#ifndef NSXMLDocumentKind
  #define NSXMLDocumentKind DDXMLDocumentKind
#endif
#ifndef NSXMLElementKind
  #define NSXMLElementKind DDXMLElementKind
#endif
#ifndef NSXMLAttributeKind
  #define NSXMLAttributeKind DDXMLAttributeKind
#endif
#ifndef NSXMLNamespaceKind
  #define NSXMLNamespaceKind DDXMLNamespaceKind
#endif
#ifndef NSXMLProcessingInstructionKind
  #define NSXMLProcessingInstructionKind DDXMLProcessingInstructionKind
#endif
#ifndef NSXMLCommentKind
  #define NSXMLCommentKind DDXMLCommentKind
#endif
#ifndef NSXMLTextKind
  #define NSXMLTextKind DDXMLTextKind
#endif
#ifndef NSXMLDTDKind
  #define NSXMLDTDKind DDXMLDTDKind
#endif
#ifndef NSXMLEntityDeclarationKind
  #define NSXMLEntityDeclarationKind DDXMLEntityDeclarationKind
#endif
#ifndef NSXMLAttributeDeclarationKind
  #define NSXMLAttributeDeclarationKind DDXMLAttributeDeclarationKind
#endif
#ifndef NSXMLElementDeclarationKind
  #define NSXMLElementDeclarationKind DDXMLElementDeclarationKind
#endif
#ifndef NSXMLNotationDeclarationKind
  #define NSXMLNotationDeclarationKind DDXMLNotationDeclarationKind
#endif

#ifndef NSXMLNodeOptionsNone
  #define NSXMLNodeOptionsNone DDXMLNodeOptionsNone
#endif
#ifndef NSXMLNodeExpandEmptyElement
  #define NSXMLNodeExpandEmptyElement DDXMLNodeExpandEmptyElement
#endif
#ifndef NSXMLNodeCompactEmptyElement
  #define NSXMLNodeCompactEmptyElement DDXMLNodeCompactEmptyElement
#endif
#ifndef NSXMLNodePrettyPrint
  #define NSXMLNodePrettyPrint DDXMLNodePrettyPrint
#endif

// KissXML has rather straight-forward memory management.
// However, if the rules are not followed,
// it is often difficult to track down the culprit.
// 
// Enabling this option will help you track down the orphaned subelement.
// More information can be found on the wiki page:
// http://code.google.com/p/kissxml/wiki/MemoryManagementThreadSafety
// 
// Please keep in mind that this option is for debugging only.
// It significantly slows down the library, and should NOT be enabled for production builds.
// 
// Note: Xcode projects created with Xcode 4 automatically define DEBUG via the project's preprocessor macros.
// If you're not using Xcode 4, or you created the project with a previous version of Xcode,
// you may need to add the DEBUG macro manually.
// 
#if DEBUG
  #define DDXML_DEBUG_MEMORY_ISSUES 1
#else
  #define DDXML_DEBUG_MEMORY_ISSUES 0
#endif

#endif