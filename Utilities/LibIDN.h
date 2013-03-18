#import <Foundation/Foundation.h>


@interface LibIDN : NSObject

/**
 * Preps a node identifier for use in a JID.
 * If the given node is invalid, this method returns nil.
 *
 * See the XMPP RFC (3920) for details.
 * 
 * Note: The prep properly converts the string to lowercase, as per the RFC.
**/
+ (NSString *)prepNode:(NSString *)node;

/**
 * Preps a domain name for use in a JID.
 * If the given domain is invalid, this method returns nil.
 * 
 * See the XMPP RFC (3920) for details.
**/
+ (NSString *)prepDomain:(NSString *)domain;

/**
 * Preps a resource identifier for use in a JID.
 * If the given node is invalid, this method returns nil.
 *
 * See the XMPP RFC (3920) for details.
 **/
+ (NSString *)prepResource:(NSString *)resource;

@end
