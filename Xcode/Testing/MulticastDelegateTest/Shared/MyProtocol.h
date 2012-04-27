#import <Foundation/Foundation.h>

@protocol MyProtocol
@optional

- (void)didSomething;
- (void)didSomethingElse:(BOOL)flag;

- (void)foundString:(NSString *)str;
- (void)foundString:(NSString *)str andNumber:(NSNumber *)num;

- (BOOL)shouldSing;
- (BOOL)shouldDance;

- (void)fastTrack;

@end
