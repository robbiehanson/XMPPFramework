#import <Foundation/Foundation.h>

@import KissXML;

@class XMPPResultSet;


@interface NSXMLElement (XEP_0059)

- (BOOL)isResultSet;
- (BOOL)hasResultSet;
- (XMPPResultSet *)resultSet;

@end
