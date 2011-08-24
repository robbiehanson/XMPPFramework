#import "XMPPJID.h"
#import "LibIDN.h"

@implementation XMPPJID

+ (BOOL)validateDomain:(NSString *)domain
{
	// Domain is the only required part of a JID
	if ((domain == nil) || ([domain length] == 0))
		return NO;
	
	// If there's an @ symbol in the domain it probably means user put @ in their username
	NSRange invalidAtRange = [domain rangeOfString:@"@"];
	if (invalidAtRange.location != NSNotFound)
		return NO;
	
	return YES;
}

+ (BOOL)validateResource:(NSString *)resource
{
	// Can't use an empty string resource name
	if ((resource != nil) && ([resource length] == 0))
		return NO;
	
	return YES;
}

+ (BOOL)validateUser:(NSString *)user domain:(NSString *)domain resource:(NSString *)resource
{
	if (![self validateDomain:domain])
		return NO;
	
	if (![self validateResource:resource])
		return NO;
	
	return YES;
}

+ (BOOL)parse:(NSString *)jidStr
	  outUser:(NSString **)user
	outDomain:(NSString **)domain
  outResource:(NSString **)resource
{
	if(user)     *user = nil;
	if(domain)   *domain = nil;
	if(resource) *resource = nil;
	
	if(jidStr == nil) return NO;
	
	NSString *rawUser = nil;
	NSString *rawDomain = nil;
	NSString *rawResource = nil;
	
	NSRange atRange = [jidStr rangeOfString:@"@"];
	
	if(atRange.location != NSNotFound)
	{
		rawUser = [jidStr substringToIndex:atRange.location];
		
		NSString *minusUser = [jidStr substringFromIndex:atRange.location+1];
		
		NSRange slashRange = [minusUser rangeOfString:@"/"];
		
		if(slashRange.location != NSNotFound)
		{
			rawDomain = [minusUser substringToIndex:slashRange.location];
			rawResource = [minusUser substringFromIndex:slashRange.location+1];
		}
		else
		{
			rawDomain = minusUser;
		}
	}
	else
	{
		NSRange slashRange = [jidStr rangeOfString:@"/"];
				
		if(slashRange.location != NSNotFound)
		{
			rawDomain = [jidStr substringToIndex:slashRange.location];
			rawResource = [jidStr substringFromIndex:slashRange.location+1];
		}
		else
		{
			rawDomain = jidStr;
		}
	}
	
	NSString *prepUser = [LibIDN prepNode:rawUser];
	NSString *prepDomain = [LibIDN prepDomain:rawDomain];
	NSString *prepResource = [LibIDN prepResource:rawResource];
	
	if([XMPPJID validateUser:prepUser domain:prepDomain resource:prepResource])
	{
		if(user)     *user = prepUser;
		if(domain)   *domain = prepDomain;
		if(resource) *resource = prepResource;
		
		return YES;
	}
	
	return NO;
}

+ (XMPPJID *)jidWithString:(NSString *)jidStr
{
	NSString *user;
	NSString *domain;
	NSString *resource;
	
	if([XMPPJID parse:jidStr outUser:&user outDomain:&domain outResource:&resource])
	{
		XMPPJID *jid = [[XMPPJID alloc] init];
		jid->user = [user copy];
		jid->domain = [domain copy];
		jid->resource = [resource copy];
		
		return [jid autorelease];
	}
	
	return nil;
}

+ (XMPPJID *)jidWithString:(NSString *)jidStr resource:(NSString *)resource
{
	if(![self validateResource:resource]) return nil;
	
	NSString *user;
	NSString *domain;
	
	if([XMPPJID parse:jidStr outUser:&user outDomain:&domain outResource:nil])
	{
		XMPPJID *jid = [[XMPPJID alloc] init];
		jid->user = [user copy];
		jid->domain = [domain copy];
		jid->resource = [resource copy];
		
		return [jid autorelease];
	}
	
	return nil;
}

+ (XMPPJID *)jidWithUser:(NSString *)user domain:(NSString *)domain resource:(NSString *)resource
{
	NSString *prepUser = [LibIDN prepNode:user];
	NSString *prepDomain = [LibIDN prepDomain:domain];
	NSString *prepResource = [LibIDN prepResource:resource];
	
	if([XMPPJID validateUser:prepUser domain:prepDomain resource:prepResource])
	{
		XMPPJID *jid = [[XMPPJID alloc] init];
		jid->user = [prepUser copy];
		jid->domain = [prepDomain copy];
		jid->resource = [prepResource copy];
		
		return [jid autorelease];
	}
	
	return nil;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Encoding, Decoding:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#if ! TARGET_OS_IPHONE
- (id)replacementObjectForPortCoder:(NSPortCoder *)encoder
{
	if([encoder isBycopy])
		return self;
	else
		return [super replacementObjectForPortCoder:encoder];
	//	return [NSDistantObject proxyWithLocal:self connection:[encoder connection]];
}
#endif

- (id)initWithCoder:(NSCoder *)coder
{
	if((self = [super init]))
	{
		if([coder allowsKeyedCoding])
		{
			user     = [[coder decodeObjectForKey:@"user"] copy];
			domain   = [[coder decodeObjectForKey:@"domain"] copy];
			resource = [[coder decodeObjectForKey:@"resource"] copy];
		}
		else
		{
			user     = [[coder decodeObject] copy];
			domain   = [[coder decodeObject] copy];
			resource = [[coder decodeObject] copy];
		}
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	if([coder allowsKeyedCoding])
	{
		[coder encodeObject:user     forKey:@"user"];
		[coder encodeObject:domain   forKey:@"domain"];
		[coder encodeObject:resource forKey:@"resource"];
	}
	else
	{
		[coder encodeObject:user];
		[coder encodeObject:domain];
		[coder encodeObject:resource];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Copying:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (id)copyWithZone:(NSZone *)zone
{
	// This class is immutable
	return [self retain];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Normal Methods:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Why didn't we just synthesize these properties?
// 
// Since these variables are readonly within the class,
// we want the synthesized methods to work like a nonatomic property.
// In order to do this, we have to mark the properties as nonatomic in the header.
// However we don't like marking the property as nonatomic in the header because
// then people might think it's not thread-safe when in fact it is.

- (NSString *)user
{
	return user; // Why didn't we just synthesize this? See comment above.
}

- (NSString *)domain
{
	return domain; // Why didn't we just synthesize this? See comment above.
}

- (NSString *)resource
{
	return resource; // Why didn't we just synthesize this? See comment above.
}

- (XMPPJID *)bareJID
{
	if(resource == nil)
	{
		return [[self retain] autorelease];
	}
	else
	{
		return [XMPPJID jidWithUser:user domain:domain resource:nil];
	}
}

- (XMPPJID *)domainJID
{
	if(user == nil && resource == nil)
	{
		return [[self retain] autorelease];
	}
	else
	{
		return [XMPPJID jidWithUser:nil domain:domain resource:nil];
	}
}

- (NSString *)bare
{
	if(user)
		return [NSString stringWithFormat:@"%@@%@", user, domain];
	else
		return domain;
}

- (NSString *)full
{
	if(user)
	{
		if(resource)
			return [NSString stringWithFormat:@"%@@%@/%@", user, domain, resource];
		else
			return [NSString stringWithFormat:@"%@@%@", user, domain];
	}
	else
	{
		if(resource)
			return [NSString stringWithFormat:@"%@/%@", domain, resource];
		else
			return domain;
	}
}

- (BOOL)isBare
{
	// From RFC 6120 Terminology:
	// 
	// The term "bare JID" refers to an XMPP address of the form <localpart@domainpart> (for an account at a server)
	// or of the form <domainpart> (for a server).
	
	return (resource == nil);
}

- (BOOL)isBareWithUser
{
	return (user != nil && resource == nil);
}

- (BOOL)isFull
{
	// From RFC 6120 Terminology:
	// 
	// The term "full JID" refers to an XMPP address of the form
	// <localpart@domainpart/resourcepart> (for a particular authorized client or device associated with an account)
	// or of the form <domainpart/resourcepart> (for a particular resource or script associated with a server).
	
	return (resource != nil);
}

- (BOOL)isFullWithUser
{
	return (user != nil && resource != nil);
}

- (BOOL)isServer
{
	return (user == nil);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark NSObject Methods:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#if MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_4
- (unsigned)hash
{
	return [[self full] hash];
}
#else
- (NSUInteger)hash
{
	return [[self full] hash];
}
#endif

- (BOOL)isEqual:(id)anObject
{
	if ([anObject isMemberOfClass:[self class]])
	{
		return [self isEqualToJID:(XMPPJID *)anObject];
	}
	return NO;
}

- (BOOL)isEqualToJID:(XMPPJID *)aJID
{
	return [self isEqualToJID:aJID options:XMPPJIDCompareFull];
}

- (BOOL)isEqualToJID:(XMPPJID *)aJID options:(XMPPJIDCompareOptions)mask
{
	if (aJID == nil) return NO;
	
	if (mask & XMPPJIDCompareUser)
	{
		if (user) {
			if (![user isEqualToString:aJID->user]) return NO;
		}
		else {
			if (aJID->user) return NO;
		}
	}
	
	if (mask & XMPPJIDCompareDomain)
	{
		if (domain) {
			if (![domain isEqualToString:aJID->domain]) return NO;
		}
		else {
			if (aJID->domain) return NO;
		}
	}
	
	if (mask & XMPPJIDCompareResource)
	{
		if (resource) {
			if (![resource isEqualToString:aJID->resource]) return NO;
		}
		else {
			if (aJID->resource) return NO;
		}
	}
	
	return YES;
}

- (NSString *)description
{
	return [self full];
}

- (void)dealloc
{
	[user release];
	[domain release];
	[resource release];
	[super dealloc];
}

@end
