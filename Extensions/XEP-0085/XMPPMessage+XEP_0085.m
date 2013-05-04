#import "XMPPMessage+XEP_0085.h"
#import "NSXMLElement+XMPP.h"


static NSString *const xmlns_chatstates = @"http://jabber.org/protocol/chatstates";

@implementation XMPPMessage (XEP_0085)

- (NSString *)chatState{
    return [[[self elementsForXmlns:xmlns_chatstates] lastObject] name];
}

- (BOOL)hasChatState
{
	return ([[self elementsForXmlns:xmlns_chatstates] count] > 0);
}

- (BOOL)isActiveChatState
{
	return ([self elementForName:@"active" xmlns:xmlns_chatstates] != nil);
}

- (BOOL)isComposingChatState
{
	return ([self elementForName:@"composing" xmlns:xmlns_chatstates] != nil);
}

- (BOOL)isPausedChatState
{
	return ([self elementForName:@"paused" xmlns:xmlns_chatstates] != nil);
}

- (BOOL)isInactiveChatState
{
	return ([self elementForName:@"inactive" xmlns:xmlns_chatstates] != nil);
}

- (BOOL)isGoneChatState
{
	return ([self elementForName:@"gone" xmlns:xmlns_chatstates] != nil);
}


- (void)addActiveChatState
{
	[self addChild:[NSXMLElement elementWithName:@"active" xmlns:xmlns_chatstates]];
}

- (void)addComposingChatState
{
	[self addChild:[NSXMLElement elementWithName:@"composing" xmlns:xmlns_chatstates]];
}

- (void)addPausedChatState
{
	[self addChild:[NSXMLElement elementWithName:@"paused" xmlns:xmlns_chatstates]];
}

- (void)addInactiveChatState
{
	[self addChild:[NSXMLElement elementWithName:@"inactive" xmlns:xmlns_chatstates]];
}

- (void)addGoneChatState
{
	[self addChild:[NSXMLElement elementWithName:@"gone" xmlns:xmlns_chatstates]];
}

@end
