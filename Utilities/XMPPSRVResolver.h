//
//  XMPPSRVResolver.h
// 
//  Originally created by Eric Chamberlain on 6/15/10.
//  Based on SRVResolver by Apple, Inc.
//  

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
extern NSString *const XMPPSRVResolverErrorDomain;
@protocol XMPPSRVResolverDelegate;
@class XMPPSRVRecord;

@interface XMPPSRVResolver : NSObject

/**
 * The delegate & delegateQueue are mandatory.
 * The resolverQueue is optional. If NULL, it will automatically create it's own internal queue.
**/
- (instancetype)initWithDelegate:(id<XMPPSRVResolverDelegate>)delegate
                   delegateQueue:(dispatch_queue_t)delegateQueue
                   resolverQueue:(nullable dispatch_queue_t)resolverQueue;

@property (strong, readonly, nullable) NSString *srvName;
@property (readonly) NSTimeInterval timeout;

- (void)startWithSRVName:(NSString *)aSRVName timeout:(NSTimeInterval)aTimeout;
- (void)stop;

+ (NSString *)srvNameFromXMPPDomain:(NSString *)xmppDomain;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol XMPPSRVResolverDelegate
@optional
- (void)xmppSRVResolver:(XMPPSRVResolver *)sender didResolveRecords:(NSArray<XMPPSRVRecord*> *)records;
- (void)xmppSRVResolver:(XMPPSRVResolver *)sender didNotResolveDueToError:(NSError *)error;
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface XMPPSRVRecord : NSObject
{
	UInt16 priority;
	UInt16 weight;
	UInt16 port;
	NSString *target;
	
	NSUInteger sum;
	NSUInteger srvResultsIndex;
}

+ (instancetype)recordWithPriority:(UInt16)priority
                            weight:(UInt16)weight
                              port:(UInt16)port
                            target:(NSString *)target;

- (instancetype)initWithPriority:(UInt16)priority
                          weight:(UInt16)weight
                            port:(UInt16)port
                          target:(NSString *)target;

@property (nonatomic, readonly) UInt16 priority;
@property (nonatomic, readonly) UInt16 weight;
@property (nonatomic, readonly) UInt16 port;
@property (nonatomic, readonly) NSString *target;

@end
NS_ASSUME_NONNULL_END
