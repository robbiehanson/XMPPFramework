#import "XMPPMessage+XEP_0085.h"
#import "NSXMLElement+XMPP.h"


static NSString *const xmlns_chatstates = @"http://jabber.org/protocol/chatstates";

@implementation XMPPMessage (XEP_0085)

- (NSString *)chatState{
    return [[[self xmpp_elementsForXmlns:xmlns_chatstates] lastObject] name];
}

- (BOOL)hasChatState
{
	return ([[self xmpp_elementsForXmlns:xmlns_chatstates] count] > 0);
}

- (BOOL)isActiveChatState
{
	return ([self xmpp_elementForName:@"active" xmlns:xmlns_chatstates] != nil);
}

- (BOOL)isComposingChatState
{
	return ([self xmpp_elementForName:@"composing" xmlns:xmlns_chatstates] != nil);
}

- (BOOL)isPausedChatState
{
	return ([self xmpp_elementForName:@"paused" xmlns:xmlns_chatstates] != nil);
}

- (BOOL)isInactiveChatState
{
	return ([self xmpp_elementForName:@"inactive" xmlns:xmlns_chatstates] != nil);
}

- (BOOL)isGoneChatState
{
	return ([self xmpp_elementForName:@"gone" xmlns:xmlns_chatstates] != nil);
}


- (void)addActiveChatState
{
	[self addChild:[NSXMLElement xmpp_elementWithName:@"active" xmlns:xmlns_chatstates]];
}

- (void)addComposingChatState
{
	[self addChild:[NSXMLElement xmpp_elementWithName:@"composing" xmlns:xmlns_chatstates]];
}

- (void)addPausedChatState
{
	[self addChild:[NSXMLElement xmpp_elementWithName:@"paused" xmlns:xmlns_chatstates]];
}

- (void)addInactiveChatState
{
	[self addChild:[NSXMLElement xmpp_elementWithName:@"inactive" xmlns:xmlns_chatstates]];
}

- (void)addGoneChatState
{
	[self addChild:[NSXMLElement xmpp_elementWithName:@"gone" xmlns:xmlns_chatstates]];
}

@end
