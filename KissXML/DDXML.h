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

#endif