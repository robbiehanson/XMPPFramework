#import "XMPPSoftwareVersion.h"
#import "XMPP.h"
#import "XMPPFramework.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

#define XMLNS_URN_XMPP_VERSION @"urn:xmpp:jabber:iq:version"

@implementation XMPPSoftwareVersion

@synthesize name = _name;
@synthesize version = _version;
@synthesize os = _os;

- (id)initWithDispatchQueue:(dispatch_queue_t)queue
{
    NSString *name = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey];
#if TARGET_OS_IPHONE
    NSString *os = [NSString stringWithFormat:@"%@ %@",[[UIDevice currentDevice] systemName],[[UIDevice currentDevice] systemVersion]];
#else
    NSString *os = [NSString stringWithFormat:@"OS X %@",[[NSProcessInfo processInfo] operatingSystemVersionString]];
#endif
    
    return [self initWithName:name version:version os:os dispatchQueue:queue];
}

- (id)initWithName:(NSString *)name
           version:(NSString *)version
                os:(NSString *)os
     dispatchQueue:(dispatch_queue_t)queue
{
    if ((self = [super initWithDispatchQueue:queue]))
	{
        NSAssert([name length], @"name MUST NOT be nil");
        NSAssert([version length], @"version MUST NOT be nil");

        _name = [name copy];
        _version = [version copy];
        _os = [os copy];
    }
    return self;
}

- (BOOL)activate:(XMPPStream *)aXmppStream
{
	if ([super activate:aXmppStream])
	{
#ifdef _XMPP_CAPABILITIES_H
		[xmppStream autoAddDelegate:self delegateQueue:moduleQueue toModulesOfClass:[XMPPCapabilities class]];
#endif
		return YES;
	}
	
	return NO;
}

- (void)deactivate
{
#ifdef _XMPP_CAPABILITIES_H
	[xmppStream removeAutoDelegate:self delegateQueue:moduleQueue fromModulesOfClass:[XMPPCapabilities class]];
#endif
	
	[super deactivate];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStreamDelegate methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
    NSXMLElement *query = [iq elementForName:@"query" xmlns:XMLNS_URN_XMPP_VERSION];
	
    if (query)
	{
        XMPPIQ *resultIQ = [XMPPIQ iqWithType:@"result" to:[iq from] elementID:[iq elementID]];
        
        NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:XMLNS_URN_XMPP_VERSION];
        [resultIQ addChild:query];
        
        NSXMLElement *nameElement = [NSXMLElement elementWithName:@"name" stringValue:self.name];
        [query addChild:nameElement];
        
        NSXMLElement *versionElement = [NSXMLElement elementWithName:@"version" stringValue:self.version];
        [query addChild:versionElement];
        
        if([self.os length])
        {
            NSXMLElement *osElement = [NSXMLElement elementWithName:@"os" stringValue:self.os];
            [query addChild:osElement];
        }
        
        [xmppStream sendElement:resultIQ];
        
        return YES;
    }

    return NO;
}

#ifdef _XMPP_CAPABILITIES_H
/**
 * If an XMPPCapabilites instance is used we want to advertise our support for XEP-0092.
 **/
- (NSArray *)myFeaturesForXMPPCapabilities:(XMPPCapabilities *)sender
{
    // This method is invoked on the moduleQueue.
    
    // <query xmlns="http://jabber.org/protocol/disco#info">
    //   ...
    //   <feature var='urn:xmpp:jabber:iq:version'/>
    //   ...
    // </query>
    
    return @[XMLNS_URN_XMPP_VERSION];
}
#endif

@end
