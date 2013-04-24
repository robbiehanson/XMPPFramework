#import "XMPPIQ+XEP_0060.h"
#import "NSXMLElement+XMPP.h"


@implementation XMPPIQ (XEP_0060)

- (NSString *)pubsubid
{
	// <iq type='result' from='pubsub.shakespeare.lit' to='francisco@denmark.lit/barracks' id='sub1'>
	//   <pubsub xmlns='http://jabber.org/protocol/pubsub'>
    //     <subscription
	//         node='princely_musings'
	//         jid='francisco@denmark.lit'
	//         subid='ba49252aaa4f5d320c24d3766f0bdcade78c78d3'
	//         subscription='subscribed'/>
	//   </pubsub>
	// </iq>
	
	NSXMLElement *pubsub = [self elementForName:@"pubsub" xmlns:XMLNS_PUBSUB];
	NSXMLElement *subscription = [pubsub elementForName:@"subscription"];
	
	return [subscription attributeStringValueForName:@"subid"];
}

@end
