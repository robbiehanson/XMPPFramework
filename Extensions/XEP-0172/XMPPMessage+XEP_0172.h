#import <Foundation/Foundation.h>
#import "XMPPMessage.h"

NS_ASSUME_NONNULL_BEGIN
@interface XMPPMessage (XEP_0172)

@property (nonatomic, readonly, nullable) NSString *nick;

- (void)addNick:(NSString *)nick;

@end
NS_ASSUME_NONNULL_END
