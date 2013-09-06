#import <Foundation/Foundation.h>
#import "XMPPStream.h"
#import "NSXMLElement+XMPP.h"

@protocol XMPPStreamPreprocessor <NSObject>

- (NSData *)processInputData:(NSData *)data;
- (NSData *)processOutputData:(NSData *)data;

@end

@protocol XMPPElementHandler <NSObject>

- (BOOL)handleElement:(NSXMLElement *)element;

@end

@interface XMPPFeature : NSObject
@property (strong, readonly) XMPPStream * xmppStream;
- (void)activate:(XMPPStream *)xmppStream;
- (void)deactivate;
- (BOOL)handleFeatures:(NSXMLElement *)features;

@end
