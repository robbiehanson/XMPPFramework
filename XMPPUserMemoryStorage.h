#import <Foundation/Foundation.h>
#import "XMPPUser.h"

#if TARGET_OS_IPHONE
  #import "DDXML.h"
#endif

@class XMPPJID;
@class XMPPPresence;
@class XMPPResourceMemoryStorage;


@interface XMPPUserMemoryStorage : NSObject <XMPPUser, NSCoding>
{
	XMPPJID *jid;
	NSMutableDictionary *itemAttributes;
	
	NSMutableDictionary *resources;
	XMPPResourceMemoryStorage *primaryResource;
	
	NSInteger tag;
}

- (id)initWithJID:(XMPPJID *)aJid;
- (id)initWithItem:(NSXMLElement *)item;

- (void)clearAllResources;

- (void)updateWithItem:(NSXMLElement *)item;
- (void)updateWithPresence:(XMPPPresence *)presence;

- (NSInteger)tag;
- (void)setTag:(NSInteger)anInt;

@end
