#import "XMPPJID.h"
#import "XMPPStringPrep.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif


@implementation XMPPJID
@synthesize user, domain, resource;

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
	
	if (atRange.location != NSNotFound)
	{
		rawUser = [jidStr substringToIndex:atRange.location];
		
		NSString *minusUser = [jidStr substringFromIndex:atRange.location+1];
		
		NSRange slashRange = [minusUser rangeOfString:@"/"];
		
		if (slashRange.location != NSNotFound)
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
				
		if (slashRange.location != NSNotFound)
		{
			rawDomain = [jidStr substringToIndex:slashRange.location];
			rawResource = [jidStr substringFromIndex:slashRange.location+1];
		}
		else
		{
			rawDomain = jidStr;
		}
	}
	
    NSString *prepUser = nil;
    NSString *prepDomain = nil;
    NSString *prepResource = nil;
    
    if (rawUser) {
        prepUser = [XMPPStringPrep prepNode:rawUser];
    }
    if (rawDomain) {
        prepDomain = [XMPPStringPrep prepDomain:rawDomain];
    }
    if (rawResource) {
        prepResource = [XMPPStringPrep prepResource:rawResource];
    }
	
	if ([XMPPJID validateUser:prepUser domain:prepDomain resource:prepResource])
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
	
	if ([XMPPJID parse:jidStr outUser:&user outDomain:&domain outResource:&resource])
	{
		XMPPJID *jid = [[XMPPJID alloc] init];
		jid->user = [user copy];
		jid->domain = [domain copy];
		jid->resource = [resource copy];
		
		return jid;
	}
	
	return nil;
}

+ (XMPPJID *)jidWithString:(NSString *)jidStr resource:(NSString *)resource
{
	NSString *prepResource = [XMPPStringPrep prepResource:resource];
	if (![self validateResource:prepResource]) return nil;
	
	NSString *user;
	NSString *domain;
	
	if ([XMPPJID parse:jidStr outUser:&user outDomain:&domain outResource:nil])
	{
		XMPPJID *jid = [[XMPPJID alloc] init];
		jid->user = [user copy];
		jid->domain = [domain copy];
		jid->resource = [prepResource copy];
		
		return jid;
	}
	
	return nil;
}

+ (XMPPJID *)jidWithUser:(NSString *)user domain:(NSString *)domain resource:(NSString *)resource
{
	NSString *prepUser = [XMPPStringPrep prepNode:user];
	NSString *prepDomain = [XMPPStringPrep prepDomain:domain];
	NSString *prepResource = [XMPPStringPrep prepResource:resource];
	
	if ([XMPPJID validateUser:prepUser domain:prepDomain resource:prepResource])
	{
		XMPPJID *jid = [[XMPPJID alloc] init];
		jid->user = [prepUser copy];
		jid->domain = [prepDomain copy];
		jid->resource = [prepResource copy];
		
		return jid;
	}
	
	return nil;
}

+ (XMPPJID *)jidWithPrevalidatedUser:(NSString *)user
                  prevalidatedDomain:(NSString *)domain
                prevalidatedResource:(NSString *)resource
{
	XMPPJID *jid = [[XMPPJID alloc] init];
	jid->user = [user copy];
	jid->domain = [domain copy];
	jid->resource = [resource copy];
	
	return jid;
}

+ (XMPPJID *)jidWithPrevalidatedUser:(NSString *)user
                  prevalidatedDomain:(NSString *)domain
                            resource:(NSString *)resource
{
	NSString *prepResource = [XMPPStringPrep prepResource:resource];
	if (![self validateResource:prepResource]) return nil;
	
	XMPPJID *jid = [[XMPPJID alloc] init];
	jid->user = [user copy];
	jid->domain = [domain copy];
	jid->resource = [prepResource copy];
	
	return jid;
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
	if ((self = [super init]))
	{
		if ([coder allowsKeyedCoding])
		{
            if([coder respondsToSelector:@selector(requiresSecureCoding)] &&
               [coder requiresSecureCoding])
            {
                user     = [[coder decodeObjectOfClass:[NSString class] forKey:@"user"] copy];
                domain   = [[coder decodeObjectOfClass:[NSString class] forKey:@"domain"] copy];
                resource = [[coder decodeObjectOfClass:[NSString class] forKey:@"resource"] copy];
            }
            else
            {
                user     = [[coder decodeObjectForKey:@"user"] copy];
                domain   = [[coder decodeObjectForKey:@"domain"] copy];
                resource = [[coder decodeObjectForKey:@"resource"] copy];
            }
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
	if ([coder allowsKeyedCoding])
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

+ (BOOL) supportsSecureCoding
{
    return YES;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Copying:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (id)copyWithZone:(NSZone *)zone
{
	// This class is immutable
	return self;
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
	if (resource == nil)
	{
		return self;
	}
	else
	{
		return [XMPPJID jidWithPrevalidatedUser:user prevalidatedDomain:domain prevalidatedResource:nil];
	}
}

- (XMPPJID *)domainJID
{
	if (user == nil && resource == nil)
	{
		return self;
	}
	else
	{
		return [XMPPJID jidWithPrevalidatedUser:nil prevalidatedDomain:domain prevalidatedResource:nil];
	}
}

- (NSString *)bare
{
	if (user)
		return [NSString stringWithFormat:@"%@@%@", user, domain];
	else
		return domain;
}

- (NSString *)full
{
	if (user)
	{
		if (resource)
			return [NSString stringWithFormat:@"%@@%@/%@", user, domain, resource];
		else
			return [NSString stringWithFormat:@"%@@%@", user, domain];
	}
	else
	{
		if (resource)
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

- (XMPPJID *)jidWithNewResource:(NSString *)newResource
{
	return [XMPPJID jidWithPrevalidatedUser:user prevalidatedDomain:domain resource:newResource];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark NSObject Methods:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSUInteger)hash
{
	// We used to do this:
	// return [[self full] hash];
	//
	// It was functional but less than optimal because it required the creation of a new NSString everytime.
	// Now the hashing of a string itself is extremely fast,
	// so combining 3 hashes is much faster than creating a new string.
	// To accomplish this we use the murmur hashing algorithm.
	// 
	// MurmurHash2 was written by Austin Appleby, and is placed in the public domain.
	// http://code.google.com/p/smhasher
	
	NSUInteger uhash = [user hash];
	NSUInteger dhash = [domain hash];
	NSUInteger rhash = [resource hash];
	
	if (NSUIntegerMax == UINT32_MAX) // Should be optimized out via compiler since these are constants
	{
		// MurmurHash2 (32-bit)
		//
		// uint32_t MurmurHash2 ( const void * key, int len, uint32_t seed )
		// 
		// Normally one would pass a chunk of data ('key') and associated data chunk length ('len').
		// Instead we're going to use our 3 hashes.
		// And we're going to randomly make up a 'seed'.
		
		const uint32_t seed = 0xa2f1b6f; // Some random value I made up
		const uint32_t len = 12;         // 3 hashes, each 4 bytes = 12 bytes
		
		// 'm' and 'r' are mixing constants generated offline.
		// They're not really 'magic', they just happen to work well.
		
		const uint32_t m = 0x5bd1e995;
		const int r = 24;
		
		// Initialize the hash to a 'random' value
		
		uint32_t h = seed ^ len;
		uint32_t k;
		
		// Mix uhash
		
		k = uhash;
		
		k *= m;
		k ^= k >> r;
		k *= m;
		
		h *= m;
		h ^= k;
		
		// Mix dhash
		
		k = dhash;
		
		k *= m;
		k ^= k >> r;
		k *= m;
		
		h *= m;
		h ^= k;
		
		// Mix rhash
		
		k = rhash;
		
		k *= m;
		k ^= k >> r;
		k *= m;
		
		h *= m;
		h ^= k;
		
		// Do a few final mixes of the hash to ensure the last few
		// bytes are well-incorporated.
		
		h ^= h >> 13;
		h *= m;
		h ^= h >> 15;
		
		return (NSUInteger)h;
	}
	else
	{
		// MurmurHash2 (64-bit)
		// 
		// uint64_t MurmurHash64A ( const void * key, int len, uint64_t seed )
		// 
		// Normally one would pass a chunk of data ('key') and associated data chunk length ('len').
		// Instead we're going to use our 3 hashes.
		// And we're going to randomly make up a 'seed'.
		
		const uint32_t seed = 0xa2f1b6f; // Some random value I made up
		const uint32_t len = 24;         // 3 hashes, each 8 bytes = 24 bytes
		
		// 'm' and 'r' are mixing constants generated offline.
		// They're not really 'magic', they just happen to work well.
		
		const uint64_t m = 0xc6a4a7935bd1e995LLU;
		const int r = 47;
		
		// Initialize the hash to a 'random' value
		
		uint64_t h = seed ^ (len * m);
		uint64_t k;
		
		// Mix uhash
		
		k = uhash;
		
		k *= m; 
		k ^= k >> r; 
		k *= m; 
		
		h ^= k;
		h *= m;
		
		// Mix dhash
		
		k = dhash;
		
		k *= m; 
		k ^= k >> r; 
		k *= m; 
		
		h ^= k;
		h *= m;
		
		// Mix rhash
		
		k = rhash;
		
		k *= m; 
		k ^= k >> r; 
		k *= m; 
		
		h ^= k;
		h *= m;
		
		// Do a few final mixes of the hash to ensure the last few
		// bytes are well-incorporated.
		
		h ^= h >> r;
		h *= m;
		h ^= h >> r;
		
		return (NSUInteger)h;
	}
}

- (BOOL)isEqual:(id)anObject
{
	if ([anObject isMemberOfClass:[self class]])
	{
		return [self isEqualToJID:(XMPPJID *)anObject options:XMPPJIDCompareFull];
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


@end
