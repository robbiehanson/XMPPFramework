#import <Foundation/Foundation.h>
#import "XMPPMessage.h"

@interface XMPPMessage (XEP_0172)

@property (nonatomic, readonly, nullable) NSString *nick;

@end
