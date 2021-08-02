#import <Foundation/Foundation.h>

@protocol XMPPTrackingInfo;

@class XMPPElement;

@class XMPPStream;

extern const NSTimeInterval XMPPIDTrackerTimeoutNone;

/**
 * A common operation in XMPP is to send some kind of request with a unique id,
 * and wait for the response to come back.
 * The most common example is sending an IQ of type='get' with a unique id, and then awaiting the response.
 * 
 * In order to properly handle the response, the id must be stored.
 * If there are multiple queries going out and/or different kinds of queries,
 * then information about the appropriate handling of the response must also be stored.
 * This may be accomplished by storing the appropriate selector, or perhaps a block handler.
 * Additionally one may need to setup timeouts and handle those properly as well.
 * 
 * This class provides the scaffolding to simplify the tasks associated with this common operation.
 * Essentially, it provides the following:
 * - a dictionary where the unique id is the key, and the needed tracking info is the object
 * - an optional timer to fire upon a timeout
 * 
 * The class is designed to be flexible.
 * You can provide a target/selector or a block handler to be invoked.
 * Additionally, you can use the basic tracking info, or you can extend it to suit your needs.
 *
 * It is best illustrated with a few examples.
 * 
 * ---- EXAMPLE 1 - SIMPLE TRACKING WITH TARGET / SELECTOR ----
 * 
 * XMPPIQ *iq = ...
 * [iqTracker addID:[iq elementID] target:self selector:@selector(processBookQuery:withInfo:) timeout:15.0];
 * 
 * - (void)processBookQueury:(XMPPIQ *)iq withInfo:(id <XMPPTrackingInfo)info {
 *    ...
 * }
 * 
 * - (BOOL)xmppStream:(XMPPStream *)stream didReceiveIQ:(XMPPIQ *)iq
 * {
 *     NSString *type = [iq type];
 *     
 *     if ([type isEqualToString:@"result"] || [type isEqualToString:@"error"])
 *     {
 *         return [iqTracker invokeForID:[iq elementID] withObject:iq];
 *     }
 *     else
 *     {
 *         ...
 *     }
 * }
 * 
 * ---- EXAMPLE 2 - SIMPLE TRACKING WITH BLOCK HANDLER ----
 * 
 * XMPPIQ *iq = ...
 * 
 * void (^blockHandler)(XMPPIQ *, id <XMPPTrackingInfo>) = ^(XMPPIQ *iq, id <XMPPTrackingInfo> info) {
 *     ...
 * };
 * [iqTracker addID:[iq elementID] block:blockHandler timeout:15.0];
 * 
 * // Same xmppStream:didReceiveIQ: as example 1
 * 
 * ---- EXAMPLE 3 - ADVANCED TRACKING ----
 * 
 * @interface PingTrackingInfo : XMPPBasicTrackingInfo
 *     ...
 * @end
 * 
 * XMPPIQ *ping = ...
 * PingTrackingInfo *pingInfo = ...
 * 
 * [iqTracker addID:[ping elementID] trackingInfo:pingInfo];
 * 
 * - (void)handlePong:(XMPPIQ *)iq withInfo:(PingTrackingInfo *)info {
 *     ...
 * }
 * 
 * // Same xmppStream:didReceiveIQ: as example 1
 *
 *
 * ---- Validating Responses ----
 *
 * XMPPIDTracker can also be used to validate that the response was from the expected jid.
 * To do this you need to initalize XMPPIDTracker with the stream where the request/response is going to be tracked.
 *
 * xmppIDTracker = [[XMPPIDTracker alloc] initWithStream:stream dispatchQueue:queue];
 *
 * You also need to supply the element (not just the ID) to the add an invoke methods.
 *
 * ---- EXAMPLE 1 - SIMPLE TRACKING WITH TARGET / SELECTOR AND VALIDATION ----
 *
 * XMPPIQ *iq = ...
 * [iqTracker addElement:iq target:self selector:@selector(processBookQuery:withInfo:) timeout:15.0];
 *
 * - (void)processBookQueury:(XMPPIQ *)iq withInfo:(id <XMPPTrackingInfo)info {
 *    ...
 * }
 *
 * - (BOOL)xmppStream:(XMPPStream *)stream didReceiveIQ:(XMPPIQ *)iq
 * {
 *     NSString *type = [iq type];
 *
 *     if ([type isEqualToString:@"result"] || [type isEqualToString:@"error"])
 *     {
 *         return [iqTracker invokeForElement:iq withObject:iq];
 *     }
 *     else
 *     {
 *         ...
 *     }
 * }
 * 
 * This class is NOT thread-safe.
 * It is designed to be used within a thread-safe context (e.g. within a single dispatch_queue).
**/
NS_ASSUME_NONNULL_BEGIN
@interface XMPPIDTracker : NSObject

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithDispatchQueue:(dispatch_queue_t)queue;

- (instancetype)initWithStream:(nullable XMPPStream *)stream dispatchQueue:(dispatch_queue_t)queue NS_DESIGNATED_INITIALIZER;

- (void)addID:(NSString *)elementID target:(nullable id)target selector:(nullable SEL)selector timeout:(NSTimeInterval)timeout;

- (void)addElement:(XMPPElement *)element target:(nullable id)target selector:(nullable SEL)selector timeout:(NSTimeInterval)timeout;

- (void)addID:(NSString *)elementID
        block:(void (^_Nullable)(id _Nullable obj, id <XMPPTrackingInfo> info))block
      timeout:(NSTimeInterval)timeout;

- (void)addElement:(XMPPElement *)element
             block:(void (^_Nullable)(id _Nullable obj, id <XMPPTrackingInfo> info))block
           timeout:(NSTimeInterval)timeout;

- (void)addID:(NSString *)elementID trackingInfo:(id <XMPPTrackingInfo>)trackingInfo;

- (void)addElement:(XMPPElement *)element trackingInfo:(id <XMPPTrackingInfo>)trackingInfo;

- (BOOL)invokeForID:(NSString *)elementID withObject:(nullable id)obj;

- (BOOL)invokeForElement:(XMPPElement *)element withObject:(nullable id)obj;

@property (nonatomic, readonly) NSUInteger numberOfIDs;

- (void)removeID:(NSString *)elementID;
- (void)removeAllIDs;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol XMPPTrackingInfo <NSObject>

@property (nonatomic, readonly) NSTimeInterval timeout;

@property (nonatomic, readwrite, copy) NSString *elementID;

@property (nonatomic, readwrite, copy) XMPPElement *element;

- (void)createTimerWithDispatchQueue:(dispatch_queue_t)queue;
- (void)cancelTimer;

- (void)invokeWithObject:(nullable id)obj;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface XMPPBasicTrackingInfo : NSObject <XMPPTrackingInfo>

- (instancetype)initWithTarget:(nullable id)target selector:(nullable SEL)selector timeout:(NSTimeInterval)timeout;
- (instancetype)initWithBlock:(void (^_Nullable)(id _Nullable obj, id <XMPPTrackingInfo> info))block timeout:(NSTimeInterval)timeout;

@property (nonatomic, readonly) NSTimeInterval timeout;

@property (nonatomic, readwrite, copy) NSString *elementID;

@property (nonatomic, readwrite, copy) XMPPElement *element;

- (void)createTimerWithDispatchQueue:(dispatch_queue_t)queue;
- (void)cancelTimer;

- (void)invokeWithObject:(nullable id)obj;

@end
NS_ASSUME_NONNULL_END
