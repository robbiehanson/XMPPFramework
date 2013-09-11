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

- (BOOL)hasActiveChatState
{
	return ([self elementForName:@"active" xmlns:xmlns_chatstates] != nil);
}

- (BOOL)hasComposingChatState
{
	return ([self elementForName:@"composing" xmlns:xmlns_chatstates] != nil);
}

- (BOOL)hasPausedChatState
{
	return ([self elementForName:@"paused" xmlns:xmlns_chatstates] != nil);
}

- (BOOL)hasInactiveChatState
{
	return ([self elementForName:@"inactive" xmlns:xmlns_chatstates] != nil);
}

- (BOOL)hasGoneChatState
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
