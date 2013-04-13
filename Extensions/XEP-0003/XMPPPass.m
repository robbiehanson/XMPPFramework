//
//  XMPPPass.m
//  XMPPFramework
//
//  Created by Sean Batson on 12-06-23.
//  Copyright (c) 2012 Baseva, Inc. All rights reserved.
//

#import "XMPPPass.h"
#import "XMPP.h"
#import "XMPPLogging.h"
#import "GCDAsyncSocket.h"
#import "NSData+XMPP.h"
#import "NSNumber+XMPP.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

// Log levels: off, error, warn, info, verbose
#if DEBUG
static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;//| XMPP_LOG_LEVEL_ERROR | XMPP_LOG_FLAG_TRACE | XMPP_LOG_LEVEL_VERBOSE;
#else
static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

#define INTEGRATE_WITH_CAPABILITIES 1

#if INTEGRATE_WITH_CAPABILITIES
#import "XMPPCapabilities.h"
#endif

#if TARGET_OS_IPHONE  
#import <UIKit/UIKit.h>
#endif

#define kModuleNameSpace  @"jabber:iq:pass"
#define PASS_REGISTRATION_REQUEST  100
#define PASS_REGISTRATION_RESPONSE 101
#define PASS_REGISTRATION_NOPORTS  102
#define PASS_REQUEST_TO_ENTITY     103
#define PASS_ACCEPT_CONNECTION     104

@implementation ServerInfo

- (NSString*)serverName
{
    return serverName;
}

- (void)setServerName:(NSString *)name
{
    serverName = name;
}

- (NSString*)serverPort
{
    return serverPort;
}

- (void)setServerPort:(NSString *)port
{
    serverPort = port;
}

@end

@implementation XMPPPass

static NSMutableArray *proxyServer;

/**
 * Called automatically (courtesy of Cocoa) before the first method of this class is called.
 * It may also be called directly, hence the safety mechanism.
 **/
+ (void)initialize
{
	static BOOL initialized = NO;
	if (!initialized)
	{
		initialized = YES;
		
		proxyServer = [[NSMutableArray alloc] initWithObjects:@"jabber.org", nil];
	}
}

+ (NSArray *)proxyServer
{
	NSArray *result = nil;
	
	@synchronized(proxyServer)
	{
		XMPPLogTrace();
		
		result = [proxyServer copy];
	}
	
	return result;
}

+ (void)setProxyServer:(NSArray *)candidates
{
	@synchronized(proxyServer)
	{
		XMPPLogTrace();
		
		[proxyServer removeAllObjects];
		[proxyServer addObjectsFromArray:candidates];
	}
}



- (BOOL)activate:(XMPPStream *)aXmppStream
{
    if ([super activate:aXmppStream])
    {
#if INTEGRATE_WITH_CAPABILITIES
        [xmppStream autoAddDelegate:self delegateQueue:moduleQueue toModulesOfClass:[XMPPCapabilities class]];
#endif
        
        return YES;
    }
    
    return NO;
}

- (void)deactivate
{
#if INTEGRATE_WITH_CAPABILITIES
    [xmppStream removeAutoDelegate:self delegateQueue:moduleQueue fromModulesOfClass:[XMPPCapabilities class]];
#endif
    
    dispatch_block_t block = ^{
        
    };
    
    if (dispatch_get_specific(moduleQueueTag))
        block();
    else
        dispatch_sync(moduleQueue, block);
    
    [super deactivate];
}



- (void)registrationRequest:(NSString*)serviceName
{
    modulestate = PASS_REGISTRATION_REQUEST;
    NSXMLElement *regreq = [NSXMLElement elementWithName:@"query" xmlns:kModuleNameSpace];
    NSXMLElement *reqexp = [NSXMLElement elementWithName:@"expire" stringValue:@"1200"];
    [regreq addChild:reqexp];
    
    NSString *proxyCanadidate = nil;
    
    if (proxyServer.count) {
        proxyCanadidate = [NSString stringWithFormat:@"pass.%@", proxyServer[0]];

        XMPPIQ *iq = [XMPPIQ iqWithType:@"set" to:[XMPPJID jidWithString:proxyCanadidate] elementID:[xmppStream generateUUID]];
        [iq addChild:reqexp];
        
        [xmppStream sendElement:iq];
    }
    
    
}

- (void)requestToEntity:(XMPPJID*)entityJID
{
    
}



- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
    NSString *type = [[iq attributeForName:@"type"] stringValue];
    
    if ([type isEqualToString:@"result"])
    {
        switch (modulestate) {
            case PASS_REGISTRATION_REQUEST:
            {
                NSXMLElement *proxy = [iq elementForName:@"query" xmlns:kModuleNameSpace];
                if (proxy)
                {
                    NSXMLElement *srvInfo = [proxy elementForName:@"server"];
                    if (srvInfo) {
                        ServerInfo *srv = [ServerInfo new];
                        srv.serverPort = [srvInfo attributeStringValueForName:@"port"];
                        srv.serverName = [srvInfo stringValue];
                        
                        [multicastDelegate xmppPass:self didReceiveRegistrationSuccess:srv];
                        
                    }
                }
            }
                break;
                
            default:
            {
                
            }
                break;
        }
    }
    else if ([type isEqualToString:@"get"])
    {
        NSXMLElement *proxy = [iq elementForName:@"query" xmlns:kModuleNameSpace];
        if (proxy)
        {
            return YES;
        }
        
    } 
    else if ([type isEqualToString:@"set"])
    {
        NSXMLElement *proxy = [iq elementForName:@"query" xmlns:kModuleNameSpace];
        if (proxy)
        {
            return YES;
        }
        
    }

    else if ([type isEqualToString:@"error"]) {
        NSXMLElement *proxy = [iq elementForName:@"error"];
        if (proxy)
        {
            NSInteger code = [proxy attributeUnsignedIntegerValueForName:@"code"];
            NSError *error = [NSError errorWithDomain:@"XEP-0003 Error" code:code userInfo:NULL];
            [multicastDelegate xmppPass:self didReceiveRegistrationFailure:error];
        }
    }
    
    return NO;
}


#if INTEGRATE_WITH_CAPABILITIES
/**
 * If an XMPPCapabilites instance is used we want to advertise our support for vcards.
 **/
- (void)xmppCapabilities:(XMPPCapabilities *)sender collectingMyCapabilities:(NSXMLElement *)query
{
    // <query xmlns="http://jabber.org/protocol/disco#info">
    //   ...
    //   <feature var="jabber:iq:version"/>
    //   ...
    // </query>
    
    NSXMLElement *feature = [NSXMLElement elementWithName:@"feature"];
    [feature addAttributeWithName:@"var" stringValue:kModuleNameSpace];
    [query addChild:feature];
    
}
#endif

@end
