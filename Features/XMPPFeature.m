#import "XMPPFeature.h"

@interface XMPPFeature ()
{
    XMPPStream *xmppStream;
    
    dispatch_queue_t featureQueue;
    void *featureQueueTag;
    
    id multicastDelegate;
}

@end

@implementation XMPPFeature
/**
 * Standard init method.
 **/
- (id)init
{
    return [self initWithDispatchQueue:NULL];
}

/**
 * Designated initializer.
 **/
- (id)initWithDispatchQueue:(dispatch_queue_t)queue
{
    if ((self = [super init]))
    {
        if (queue)
        {
            featureQueue = queue;
#if !OS_OBJECT_USE_OBJC
            dispatch_retain(featureQueue);
#endif
        }
        else
        {
            const char *featureQueueName = [[self featureName] UTF8String];
            featureQueue = dispatch_queue_create(featureQueueName, NULL);
        }
        
        featureQueueTag = &featureQueueTag;
        dispatch_queue_set_specific(featureQueue, featureQueueTag, featureQueueTag, NULL);
        
        multicastDelegate = [[GCDMulticastDelegate alloc] init];
    }
    return self;
}

- (void)dealloc
{
#if !OS_OBJECT_USE_OBJC
    dispatch_release(featureQueue);
#endif
}


- (BOOL)activate:(XMPPStream *)aXmppStream
{
    __block BOOL result = YES;
    
    dispatch_block_t block = ^{
        
        if (xmppStream != nil)
        {
            result = NO;
        }
        else
        {
            xmppStream = aXmppStream;
            
            [xmppStream addDelegate:self delegateQueue:featureQueue];
            [self.xmppStream addFeature:self];
        }
    };
    
    if (dispatch_get_specific(featureQueueTag))
        block();
    else
        dispatch_sync(featureQueue, block);
    
    return result;
}

- (void)deactivate
{
    dispatch_block_t block = ^{
        
        if (xmppStream)
        {
            [xmppStream removeDelegate:self delegateQueue:featureQueue];
            [self.xmppStream removeFeature:self];
            
            xmppStream = nil;
        }
    };
    
    if (dispatch_get_specific(featureQueueTag))
        block();
    else
        dispatch_sync(featureQueue, block);
    
}


- (BOOL)handleFeatures:(NSXMLElement *)features
{
    return NO;
}

- (BOOL)handleElement:(NSXMLElement *)element
{
    return NO;
}

- (dispatch_queue_t)featureQueue
{
    return featureQueue;
}

- (void *)featureQueueTag
{
    return featureQueueTag;
}

- (XMPPStream *)xmppStream
{
    if (dispatch_get_specific(featureQueueTag))
    {
        return xmppStream;
    }
    else
    {
        __block XMPPStream *result;
        
        dispatch_sync(featureQueue, ^{
            result = xmppStream;
        });
        
        return result;
    }
}

- (NSString *)featureName
{
    // Override me (if needed) to provide a customized module name.
    // This name is used as the name of the dispatch_queue which could aid in debugging.
    
    return NSStringFromClass([self class]);
}

@end
