#import <Foundation/Foundation.h>

@class AsyncSocket;
@class Service;

@interface StreamController : NSObject
{
	AsyncSocket *listeningSocket;
	NSMutableArray *sockets;
	NSMutableArray *xmppStreams;
	NSMutableDictionary *serviceDict;
}

+ (StreamController *)sharedInstance;

- (void)startListening;
- (void)stopListening;

- (UInt16)listeningPort;

@end
