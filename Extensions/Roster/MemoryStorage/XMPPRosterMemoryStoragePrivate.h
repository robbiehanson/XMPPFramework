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

#define XMPP_USER_NO_CHANGE        0
#define XMPP_USER_ADDED_RESOURCE   1
#define XMPP_USER_UPDATED_RESOURCE 2
#define XMPP_USER_REMOVED_RESOURCE 3


@interface XMPPUserMemoryStorage ()

- (id)initWithJID:(XMPPJID *)aJid;
- (id)initWithItem:(NSXMLElement *)item;

- (void)updateWithItem:(NSXMLElement *)item;

- (int)updateWithPresence:(XMPPPresence *)presence
            resourceClass:(Class)resourceClass
           andGetResource:(XMPPResourceMemoryStorage **)resourcePtr;

- (void)clearAllResources;

#if TARGET_OS_IPHONE
@property (nonatomic, retain, readwrite) UIImage *photo;
#else
@property (nonatomic, retain, readwrite) NSImage *photo;
#endif

@end

@interface XMPPResourceMemoryStorage ()

- (id)initWithPresence:(XMPPPresence *)aPresence;

- (void)updateWithPresence:(XMPPPresence *)presence;

- (XMPPPresence *)presence;

@end
