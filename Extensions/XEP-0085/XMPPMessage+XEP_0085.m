#import "XMPPMessage+XEP_0085.h"
#import "NSXMLElement+XMPP.h"

NSString *const ChatStatesXmlns = @"http://jabber.org/protocol/chatstates";

@implementation XMPPMessage (XEP_0085)

- (NSString*)chatState {
    return self.chatState;
}

- (NSString *)chatStateValue{
    return [[[self elementsForXmlns:ChatStatesXmlns] lastObject] name];
}

- (BOOL)hasChatState
{
	return ([[self elementsForXmlns:ChatStatesXmlns] count] > 0);
}

- (BOOL)hasActiveChatState
{
	return ([self elementForName:@"active" xmlns:ChatStatesXmlns] != nil);
}

- (BOOL)hasComposingChatState
{
	return ([self elementForName:@"composing" xmlns:ChatStatesXmlns] != nil);
}

- (BOOL)hasPausedChatState
{
	return ([self elementForName:@"paused" xmlns:ChatStatesXmlns] != nil);
}

- (BOOL)hasInactiveChatState
{
	return ([self elementForName:@"inactive" xmlns:ChatStatesXmlns] != nil);
}

- (BOOL)hasGoneChatState
{
	return ([self elementForName:@"gone" xmlns:ChatStatesXmlns] != nil);
}


- (void)addActiveChatState
{
	[self addChild:[NSXMLElement elementWithName:@"active" xmlns:ChatStatesXmlns]];
}

- (void)addComposingChatState
{
	[self addChild:[NSXMLElement elementWithName:@"composing" xmlns:ChatStatesXmlns]];
}

- (void)addPausedChatState
{
	[self addChild:[NSXMLElement elementWithName:@"paused" xmlns:ChatStatesXmlns]];
}

- (void)addInactiveChatState
{
	[self addChild:[NSXMLElement elementWithName:@"inactive" xmlns:ChatStatesXmlns]];
}

- (void)addGoneChatState
{
	[self addChild:[NSXMLElement elementWithName:@"gone" xmlns:ChatStatesXmlns]];
}

@end
