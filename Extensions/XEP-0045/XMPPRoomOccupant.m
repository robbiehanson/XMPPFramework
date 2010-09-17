//
// XMPPRoomOccupant
// A chat room. XEP-0045 Implementation.
//

#import "XMPPRoomOccupant.h"


@implementation XMPPRoomOccupant

@synthesize jid;
@synthesize role, nick;

/////////////////////////////////////////////////
#pragma mark Properties
/////////////////////////////////////////////////
/* jabber id */
- (XMPPJID *)jid {
	return jid;
}

- (void)setJid:(XMPPJID *)ajid {
	[jid release];
	jid = [ajid retain];
}
/* role */
- (NSString *)role {
	return role;
}

- (void)setRole:(NSString *)aString {
	if((!role && !aString) || (role && aString && [role isEqualToString:aString])) return;
	[role release];
	role = [aString copy];
}

/* nick */
- (NSString *)nick {
	return nick;
}

- (void)setNick:(NSString *)aString {
	if((!nick && !aString) || (nick && aString && [nick isEqualToString:aString])) return;
	[nick release];
	nick = [aString copy];
}

/////////////////////////////////////////////////
#pragma mark Destructor Methods
/////////////////////////////////////////////////

- (void)dealloc {
	[jid release];
	[role release];
	[nick release];
	[super dealloc];
}

@end
