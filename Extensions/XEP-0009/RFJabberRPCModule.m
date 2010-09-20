//
//  RFJabberRPCModule.m
//  XEP-0009
//
//  Created by Eric Chamberlain on 5/16/10.
//  Copyright 2010 RF.com. All rights reserved.
//

#import "RFJabberRPCModule.h"
#import "XMPP.h"
#import "XMPPIQ+JabberRPC.h"
#import "XMPPIQ+JabberRPCResonse.h"

// can turn off if not acting as a Jabber-RPC server 
#define INTEGRATE_WITH_CAPABILITIES 1

#if INTEGRATE_WITH_CAPABILITIES
#import "XMPPCapabilities.h"
#endif

#pragma mark Constants
NSString *const RFJabberRPCErrorDomain = @"RFJabberRPCErrorDomain";

@interface RPCID : NSObject
{
	NSString *_rpcID;
	NSTimer *_timer;
}

@property(nonatomic,retain) NSString *rpcID;
@property(nonatomic,retain) NSTimer *timer;

-(id)initWithRpcID:(NSString *)rpcID timer:(NSTimer *)timer;

@end

@implementation RPCID

@synthesize rpcID = _rpcID;
@synthesize timer = _timer;

- (id)initWithRpcID:(NSString *)rpcID timer:(NSTimer *)timer {
	if (self = [super init]) {
		self.rpcID = rpcID;
		self.timer = timer;
	}
	return self;
}

- (BOOL)isEqual:(id)anObject {
	return [self.rpcID isEqual:anObject];
}

- (NSUInteger)hash {
	return [self.rpcID hash];
}

- (void)dealloc {
	[_rpcID release];
	[_timer release];
	[super dealloc];
}

@end



@interface RFJabberRPCModule()

@property(nonatomic,retain) NSMutableArray *rpcIDs;

@end


@implementation RFJabberRPCModule

@synthesize rpcIDs = _rpcIDs;
@synthesize timeout = _timeout;

#pragma mark -
#pragma mark Init/dealloc

- (id)initWithStream:(XMPPStream *)aXmppStream
{
	if ((self = [super initWithStream:aXmppStream]))
	{
		self.rpcIDs = [[[NSMutableArray alloc] initWithCapacity:5] autorelease];
		self.timeout = 5.0;
		
#if INTEGRATE_WITH_CAPABILITIES
		[xmppStream autoAddDelegate:self toModulesOfClass:[XMPPCapabilities class]];
#endif
	}
	return self;
}

- (void)dealloc
{
#if INTEGRATE_WITH_CAPABILITIES
	[xmppStream removeAutoDelegate:self fromModulesOfClass:[XMPPCapabilities class]];
#endif
	
	[_rpcIDs release];
	[super dealloc];
}





#pragma mark -
#pragma mark Send RPC

-(NSString *)sendRpcTo:(XMPPJID *)jid methodName:(NSString *)method parameters:(NSArray *)parameters {
	return [self sendRpcIQ:[XMPPIQ rpcTo:jid methodName:method parameters:parameters]];
}

-(NSString *)sendRpcIQ:(XMPPIQ *)iq {
	NSString *elementID = [[iq elementID] copy];
	
	NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:self.timeout 
													  target:self 
													selector:@selector(timeout:) 
													userInfo:elementID repeats:NO];
	RPCID *rpcID = [[RPCID alloc] initWithRpcID:elementID timer:timer];
	
	[self.rpcIDs addObject:rpcID];
	[rpcID release];
	
	[xmppStream sendElement:iq];
	
	return [elementID autorelease];
}

-(void)timeoutRemoveRpcID:(NSString *)rpcID {
	[self.rpcIDs removeObject:rpcID];
}

#pragma mark -
#pragma mark NSTimer methods

- (void)timeout:(NSTimer *)timer {
	
	[self timeoutRemoveRpcID:[timer userInfo]];
	
	NSError *error = [NSError errorWithDomain:RFJabberRPCErrorDomain 
										 code:1400 
									 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:	
											   @"Request timed out",@"error",
											   nil]];
	
	[multicastDelegate jabberRPC:self elementID:[timer userInfo] didReceiveError:error];
}


#pragma mark -
#pragma mark XMPPStream delegate

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{	
	if ([iq isJabberRPC]) {
		//NSLog(@"%s",__PRETTY_FUNCTION__);
		if ([iq isResultIQ] || [iq isErrorIQ])
		{
			// Example:
			// 
			// <iq from="deusty.com" to="robbiehanson@deusty.com/work" id="abc123" type="result"/>
			
			NSString *rpcID = [iq elementID];
			
			// check if this is a JabberRPC query
			// we could check the query element, but we should be able to do a lookup based on the unique elementID
			// because we send an ID, we should get one back
			NSUInteger rpcIndex = [self.rpcIDs indexOfObject:rpcID];
			if (rpcIndex == NSNotFound)
			{
				return NO;
			}
			
			//NSLog(@"%s one of ours!", __PRETTY_FUNCTION__);
			[[(RPCID *)[self.rpcIDs objectAtIndex:rpcIndex] timer] invalidate];
			[self.rpcIDs removeObjectAtIndex:rpcIndex];
			
			if ([iq isResultIQ]) {
				id response;
				NSError *error = nil;
				
				//TODO: parse iq and generate response.
				response = [iq methodResponse:&error];
				
				if (error == nil) {
					[multicastDelegate jabberRPC:self elementID:[iq elementID] didReceiveMethodResponse:response];
				} else {
					[multicastDelegate jabberRPC:self elementID:[iq elementID] didReceiveError:error];
				}
				
			} else {
				
				// TODO: implement error parsing
				// not much specified in XEP, only 403 forbidden error
				NSXMLElement *errorElement = [iq childErrorElement];
				NSError *error = [NSError errorWithDomain:RFJabberRPCErrorDomain 
													 code:[errorElement attributeIntValueForName:@"code"] 
												 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:	
														   [errorElement attributesAsDictionary],@"error",
														   [[errorElement childAtIndex:0] name], @"condition",
														   iq,@"iq",
														   nil]];
				
				[multicastDelegate jabberRPC:self elementID:[iq elementID] didReceiveError:error];
			}
			
#if INTEGRATE_WITH_CAPABILITIES
		} else if ([iq isSetIQ]) {
			// we would receive set when implementing Jabber-RPC server
			
			[multicastDelegate jabberRPC:self didReceiveSetIQ:iq];
#endif		
		}
		
		// Jabber-RPC doesn't use get iq type
	}
	return NO;
}






#pragma mark -
#pragma mark XMPPCapabilities delegate

#if INTEGRATE_WITH_CAPABILITIES
/**
 * If an XMPPCapabilites instance is used we want to advertise our support for JabberRPC.
 **/
- (void)xmppCapabilities:(XMPPCapabilities *)sender willSendMyCapabilities:(NSXMLElement *)query
{
	// <query xmlns="http://jabber.org/protocol/disco#info">
	//   ...
	//   <identity category='automation' type='rpc'/>
    //	 <feature var='jabber:iq:rpc'/>
	//   ...
	// </query>
	[query addChild:[XMPPIQ elementRpcIdentity]];
	[query addChild:[XMPPIQ elementRpcFeature]];
}
#endif


@end
