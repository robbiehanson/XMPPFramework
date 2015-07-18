#import <Foundation/Foundation.h>
#import "XMPPStream.h"
#import "XMPPModule.h"
#import "NSXMLElement+XMPP.h"

@protocol XMPPStreamPreprocessor <NSObject>

- (NSData *)processInputData:(NSData *)data;
- (NSData *)processOutputData:(NSData *)data;

@end

@protocol XMPPElementHandler <NSObject>

- (BOOL)handleElement:(NSXMLElement *)element;

@end

@interface XMPPFeature : NSObject <XMPPStreamDelegate>

@property (readonly) dispatch_queue_t featureQueue;
@property (readonly) void *featureQueueTag;
@property (strong, readonly) XMPPStream * xmppStream;

- (BOOL)activate:(XMPPStream *)xmppStream;
- (void)deactivate;
- (BOOL)handleFeatures:(NSXMLElement *)features;

@end
