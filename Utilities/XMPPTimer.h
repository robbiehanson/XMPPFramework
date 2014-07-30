#import <Foundation/Foundation.h>

/**
 * This class is a simple wrapper around dispatch_source_t timers.
 * 
 * The primary motivation for this is to allow timers to be stored in collections.
 * But the class also makes it easier to code timers, as it simplifies the API.
**/
@interface XMPPTimer : NSObject

/**
 * Creates an instance of a timer that will fire on the given queue.
 * It will invoke the given event handler block when it fires.
**/
- (instancetype)initWithQueue:(dispatch_queue_t)queue eventHandler:(dispatch_block_t)block;

/**
 * Starts the timer.
 * It will first fire after the timeout.
 * After that, it will continue to fire every interval.
 *
 * The interval is optional.
 * If interval is zero (or negative), it will not use an interval (will only fire once after the timeout).
 *
 * This method can only be called once.
**/
- (void)startWithTimeout:(NSTimeInterval)timeout interval:(NSTimeInterval)interval;

/**
 * Allows you to update an already started timer.
 * 
 * The new timeout that you pass can be applied to 'now' or to the original start time of the timer.
**/
- (void)updateTimeout:(NSTimeInterval)timeout fromOriginalStartTime:(BOOL)useOriginalStartTime;

/**
 * Cancels the timer so that it won't fire.
**/
- (void)cancel;

@end
