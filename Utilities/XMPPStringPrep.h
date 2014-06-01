#import <Foundation/Foundation.h>


@interface XMPPStringPrep : NSObject

/**
 * Preps a node identifier for use in a JID.
 * If the given node is invalid, this method returns nil.
 *
 * See the XMPP RFC (6120) for details.
 * 
 * Note: The prep properly converts the string to lowercase, as per the RFC.
**/
+ (NSString *)prepNode:(NSString *)node;

/**
 * Preps a domain name for use in a JID.
 * If the given domain is invalid, this method returns nil.
 * 
 * See the XMPP RFC (6120) for details.
**/
+ (NSString *)prepDomain:(NSString *)domain;

/**
 * Preps a resource identifier for use in a JID.
 * If the given node is invalid, this method returns nil.
 *
 * See the XMPP RFC (6120) for details.
 **/
+ (NSString *)prepResource:(NSString *)resource;

/**
 * Preps a password with SASLprep profile.
 * If the given string is invalid, this method returns nil.
 *
 * See the SCRAM RFC (5802) for details.
 **/

+ (NSString *) prepPassword:(NSString *)password;

@end
