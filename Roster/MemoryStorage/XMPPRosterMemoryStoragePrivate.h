#import "XMPPUserMemoryStorage.h"
#import "XMPPResourceMemoryStorage.h"

/**
 * The following methods are designed to be invoked ONLY from
 * within the XMPPRosterMemoryStorage implementation.
 * 
 * Warning: XMPPUserMemoryStorage and XMPPResourceMemoryStorage are not explicitly thread-safe.
 * Only copies that are no longer being actively
 * altered by the XMPPRosterMemoryStorage class should be considered read-only and therefore thread-safe.
**/

@interface XMPPUserMemoryStorage (Internal)

- (id)initWithJID:(XMPPJID *)aJid;
- (id)initWithItem:(NSXMLElement *)item;

- (void)clearAllResources;

- (void)updateWithItem:(NSXMLElement *)item;
- (void)updateWithPresence:(XMPPPresence *)presence;

- (NSInteger)tag;
- (void)setTag:(NSInteger)anInt;

@end

@interface XMPPResourceMemoryStorage (Internal)

- (id)initWithPresence:(XMPPPresence *)aPresence;

- (void)updateWithPresence:(XMPPPresence *)presence;

- (XMPPPresence *)presence;

@end
