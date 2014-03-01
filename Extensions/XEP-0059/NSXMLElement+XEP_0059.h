#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE
    #import "DDXML.h"
#endif

@class XMPPResultSet;


@interface NSXMLElement (XEP_0059)

- (BOOL)isResultSet;
- (BOOL)hasResultSet;
- (XMPPResultSet *)resultSet;

@end
