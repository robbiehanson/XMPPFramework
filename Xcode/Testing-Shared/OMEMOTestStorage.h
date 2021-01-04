//
//  OMEMOTestStorage.h
//  XMPPFrameworkTests
//
//  Created by Christopher Ballinger on 9/23/16.
//
//

#import <Foundation/Foundation.h>
@import XMPPFramework;

NS_ASSUME_NONNULL_BEGIN
@interface OMEMOTestStorage : NSObject <OMEMOStorageDelegate>

@property (nonatomic, strong, readonly) OMEMOBundle *myBundle;
@property (nonatomic, weak, readonly) OMEMOModule *omemoModule;

- (instancetype) initWithMyBundle:(OMEMOBundle*)myBundle;

+ (OMEMOBundle*) testBundle:(OMEMOModuleNamespace)ns;

@end
NS_ASSUME_NONNULL_END
