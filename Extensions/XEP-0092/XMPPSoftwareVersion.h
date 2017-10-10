#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE
    #import <UIKit/UIKit.h>
#else
    #import <Cocoa/Cocoa.h>
#endif

#import "XMPPModule.h"

NS_ASSUME_NONNULL_BEGIN
@interface XMPPSoftwareVersion : XMPPModule

@property (copy,readonly) NSString *name;
@property (copy,readonly) NSString *version;
@property (copy,readonly) NSString *os;

- (instancetype)initWithName:(NSString *)name
                     version:(NSString *)version
                          os:(NSString *)os
               dispatchQueue:(dispatch_queue_t)queue NS_DESIGNATED_INITIALIZER;

@end
NS_ASSUME_NONNULL_END
