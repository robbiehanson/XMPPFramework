#import <Foundation/Foundation.h>
@class MulticastDelegateListNode;


@interface MulticastDelegate : NSObject
{
	NSUInteger currentInvocationIndex;
	MulticastDelegateListNode *delegateList;
}

- (void)addDelegate:(id)delegate;
- (void)removeDelegate:(id)delegate;

- (void)removeAllDelegates;

- (NSUInteger)count;

@end
