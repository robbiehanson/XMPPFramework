#import <Foundation/Foundation.h>
#import "XMPPPresence.h"

@interface XMPPPresence (XEP_0172)

@property (nonatomic, readonly, nullable) NSString *nick;

@end
