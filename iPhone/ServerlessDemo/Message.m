#import "Message.h"
#import "Service.h"

@implementation Message

@dynamic content;
@dynamic outbound;
@dynamic read;
@dynamic timeStamp;

@dynamic service;

@dynamic isOutbound;
@dynamic hasBeenRead;

- (BOOL)isOutbound
{
    return [[self outbound] boolValue];
}

- (void)setIsOutbound:(BOOL)flag
{
    [self setOutbound:[NSNumber numberWithBool:flag]];
}

- (BOOL)hasBeenRead
{
    return [[self read] boolValue];
}

- (void)setHasBeenRead:(BOOL)flag
{
	if (flag != [self hasBeenRead])
	{
		[self.service willChangeValueForKey:@"messages"];
		
		[self setRead:[NSNumber numberWithBool:flag]];
		
		[self.service didChangeValueForKey:@"messages"];
	}
}

@end
