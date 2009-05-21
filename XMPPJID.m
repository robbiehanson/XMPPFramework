#import "XMPPJID.h"
#import "LibIDN.h"

@implementation XMPPJID

+ (BOOL)validateUser:(NSString *)user domain:(NSString *)domain resource:(NSString *)resource
{
	// Domain is the only required part of a JID
	if((domain == nil) || ([domain length] == 0)) return NO;
	
	// If there's an @ symbol in the domain it probably means user put @ in their username
	NSRange invalidAtRange = [domain rangeOfString:@"@"];
	if(invalidAtRange.location != NSNotFound) return NO;
	
	// Can't use an empty string resource name
	if((resource != nil) && ([resource length] == 0)) return NO;
	
	return YES;
}

+ (BOOL)parse:(NSString *)jidStr
	  outUser:(NSString **)user
	outDomain:(NSString **)domain
  outResource:(NSString **)resource
{
	*user = nil;
	*domain = nil;
	*resource = nil;
	
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
		*user = prepUser;
		*domain = prepDomain;
		*resource = prepResource;
		
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
	NSString *user;
	NSString *domain;
	NSString *ignore;
	
	if([XMPPJID parse:jidStr outUser:&user outDomain:&domain outResource:&ignore])
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
		return [NSDistantObject proxyWithLocal:self connection:[encoder connection]];
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

- (NSString *)user
{
	return user;
}

- (NSString *)domain
{
	return domain;
}

- (NSString *)resource
{
	return resource;
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
	if([anObject isMemberOfClass:[self class]])
	{
		XMPPJID *aJID = (XMPPJID *)anObject;
		
		return [[self full] isEqualToString:[aJID full]];
	}
	return NO;
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
