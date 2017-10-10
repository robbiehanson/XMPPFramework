
#import "NSXMLElement+XMPP.h"

NS_ASSUME_NONNULL_BEGIN
@interface NSXMLElement (XEP0352)

+ (instancetype)indicateInactiveElement;
+ (instancetype)indicateActiveElement;

@end
NS_ASSUME_NONNULL_END
