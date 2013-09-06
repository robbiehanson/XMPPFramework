#import <Foundation/Foundation.h>
#import "XMPPFeature.h"

@interface XMPPCompression : XMPPFeature <XMPPStreamPreprocessor, XMPPElementHandler>
@property (nonatomic, copy, readonly) NSString *compressionMethod;
@end