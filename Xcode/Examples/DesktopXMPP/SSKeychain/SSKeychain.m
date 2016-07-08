//
//  SSKeychain.m
//  SSToolkit
//
//  Created by Sam Soffes on 5/19/10.
//  Copyright (c) 2009-2011 Sam Soffes. All rights reserved.
//

#import "SSKeychain.h"

NSString *const kSSKeychainErrorDomain = @"com.samsoffes.sskeychain";

NSString *const kSSKeychainAccountKey = @"acct";
NSString *const kSSKeychainCreatedAtKey = @"cdat";
NSString *const kSSKeychainClassKey = @"labl";
NSString *const kSSKeychainDescriptionKey = @"desc";
NSString *const kSSKeychainLabelKey = @"labl";
NSString *const kSSKeychainLastModifiedKey = @"mdat";
NSString *const kSSKeychainWhereKey = @"svce";

@interface SSKeychain ()
+ (NSMutableDictionary *)_queryForService:(NSString *)service account:(NSString *)account;
@end

@implementation SSKeychain

#pragma mark - Getting Accounts

+ (NSArray *)allAccounts {
    return [self accountsForService:nil error:nil];
}


+ (NSArray *)allAccounts:(NSError **)error {
    return [self accountsForService:nil error:error];
}


+ (NSArray *)accountsForService:(NSString *)service {
    return [self accountsForService:service error:nil];
}


+ (NSArray *)accountsForService:(NSString *)service error:(NSError **)error {
    OSStatus status = SSKeychainErrorBadArguments;
	CFArrayRef result = NULL;
    NSMutableDictionary *query = [self _queryForService:service account:nil];
    [query setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnAttributes];
    [query setObject:(id)kSecMatchLimitAll forKey:(id)kSecMatchLimit];
    status = SecItemCopyMatching((CFDictionaryRef)query, (CFTypeRef *)&result);
    if (status != noErr && error != NULL) {
		*error = [NSError errorWithDomain:kSSKeychainErrorDomain code:status userInfo:nil];
	}
    return [(NSArray *)result autorelease];
}


#pragma mark - Getting Passwords

+ (NSString *)passwordForService:(NSString *)service account:(NSString *)account {
	return [self passwordForService:service account:account error:nil];
}


+ (NSString *)passwordForService:(NSString *)service account:(NSString *)account error:(NSError **)error {
    OSStatus status = SSKeychainErrorBadArguments;
	NSString *result = nil;
	if (service && account) {
		CFDataRef data = NULL;
		NSMutableDictionary *query = [self _queryForService:service account:account];
		[query setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnData];
		[query setObject:(id)kSecMatchLimitOne forKey:(id)kSecMatchLimit];
		status = SecItemCopyMatching((CFDictionaryRef)query, (CFTypeRef *)&data);
		if (status == noErr && CFDataGetLength(data) > 0) {
			result = [[NSString alloc] initWithData:(NSData *)data encoding:NSUTF8StringEncoding];
		}
		if (data != NULL) { CFRelease(data); }
	}
	if (status != noErr && error != NULL) {
		*error = [NSError errorWithDomain:kSSKeychainErrorDomain code:status userInfo:nil];
	}
	return [result autorelease];
}


#pragma Deleting Passwords

+ (BOOL)deletePasswordForService:(NSString *)service account:(NSString *)account {
	return [self deletePasswordForService:service account:account error:nil];
}


+ (BOOL)deletePasswordForService:(NSString *)service account:(NSString *)account error:(NSError **)error {
	OSStatus status = SSKeychainErrorBadArguments;
	if (service && account) {
		NSMutableDictionary *query = [self _queryForService:service account:account];
		status = SecItemDelete((CFDictionaryRef)query);
	}
	if (status != noErr && error != NULL) {
		*error = [NSError errorWithDomain:kSSKeychainErrorDomain code:status userInfo:nil];
	}
	return (status == noErr);
    
}


#pragma mark - Setting Passwords

+ (BOOL)setPassword:(NSString *)password forService:(NSString *)service account:(NSString *)account {
	return [self setPassword:password forService:service account:account error:nil];
}


+ (BOOL)setPassword:(NSString *)password forService:(NSString *)service account:(NSString *)account error:(NSError **)error {
	OSStatus status = SSKeychainErrorBadArguments;
	if (password && service && account) {
        [self deletePasswordForService:service account:account];
        NSMutableDictionary *query = [self _queryForService:service account:account];
        NSData *data = [password dataUsingEncoding:NSUTF8StringEncoding];
        [query setObject:data forKey:(id)kSecValueData];
        status = SecItemAdd((CFDictionaryRef)query, NULL);
	}
	if (status != noErr && error != NULL) {
		*error = [NSError errorWithDomain:kSSKeychainErrorDomain code:status userInfo:nil];
	}
	return (status == noErr);
}


#pragma mark - Private

+ (NSMutableDictionary *)_queryForService:(NSString *)service account:(NSString *)account {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithCapacity:3];
    [dictionary setObject:(id)kSecClassGenericPassword forKey:(id)kSecClass];
    if (service) {
		[dictionary setObject:service forKey:(id)kSecAttrService];
	}
    if (account) {
		[dictionary setObject:account forKey:(id)kSecAttrAccount];
	}
    return dictionary;
}

@end
