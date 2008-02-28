#import <Cocoa/Cocoa.h>


@interface XMPPUser : NSObject
{
	NSMutableDictionary *itemAttributes;
	
	NSString *presence_type;
	NSString *presence_show;
	NSString *presence_status;
}

- (id)initWithItem:(NSXMLElement *)item;

- (BOOL)isOnline;
- (BOOL)isPendingApproval;

- (NSString *)jid;
- (NSString *)name;
- (NSString *)show;
- (NSString *)status;

- (void)updateWithItem:(NSXMLElement *)iq;
- (void)updateWithPresence:(NSXMLElement *)presence;

- (void)setAsOffline;

- (NSComparisonResult)compareByName:(XMPPUser *)user;
- (NSComparisonResult)compareByName:(XMPPUser *)user options:(unsigned)mask;

- (NSComparisonResult)compareByAvailabilityName:(XMPPUser *)user;
- (NSComparisonResult)compareByAvailabilityName:(XMPPUser *)user options:(unsigned)mask;

@end
