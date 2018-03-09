#import <Foundation/Foundation.h>
#import "XMPPPresence.h"

NS_ASSUME_NONNULL_BEGIN
@interface XMPPPresence (XEP_0172)

@property (nonatomic, readonly, nullable) NSString *nick;

- (void)addNick:(NSString *)nick;

@end
NS_ASSUME_NONNULL_END
