#import <Foundation/Foundation.h>

@class GCDAsyncSocket;
@class Service;

@interface StreamController : NSObject
{
	GCDAsyncSocket *listeningSocket;
	NSMutableArray *xmppStreams;
	NSMutableDictionary *serviceDict;
}

+ (StreamController *)sharedInstance;

- (void)startListening;
- (void)stopListening;

- (UInt16)listeningPort;

@end
