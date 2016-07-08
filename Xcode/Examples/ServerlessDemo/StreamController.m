#import "StreamController.h"
#import "ServerlessDemoAppDelegate.h"
#import "GCDAsyncSocket.h"
#import "Service.h"
#import "Message.h"
#import "XMPP.h"
#import "NSXMLElement+XMPP.h"
#import "NSString+DDXML.h"
#import "DDLog.h"

// Log levels: off, error, warn, info, verbose
static const int ddLogLevel = LOG_LEVEL_VERBOSE;


@implementation StreamController

static StreamController *sharedInstance;

+ (void)initialize
{
	static BOOL initialized = NO;
	if(!initialized)
	{
		initialized = YES;
		sharedInstance = [[StreamController alloc] init];
	}
}

- (id)init
{
	// Only allow one instance of this class to ever be created
	if(sharedInstance)
	{
		return nil;
	}
	
	if((self = [super init]))
	{
		xmppStreams = [[NSMutableArray alloc] initWithCapacity:4];
		serviceDict = [[NSMutableDictionary alloc] initWithCapacity:4];
	}
	return self;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Public API
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (StreamController *)sharedInstance
{
	return sharedInstance;
}

- (void)startListening
{
	if (listeningSocket == nil)
	{
		listeningSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
	}
	
	NSError *error = nil;
	if (![listeningSocket acceptOnPort:0 error:&error])
	{
		DDLogError(@"Error setting up socket: %@", error);
	}
}

- (void)stopListening
{
	[listeningSocket disconnect];
}

- (UInt16)listeningPort
{
	return [listeningSocket localPort];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Private API
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSManagedObjectContext *)managedObjectContext
{
	ServerlessDemoAppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
	return appDelegate.managedObjectContext;
}

- (XMPPJID *)myJID
{
	ServerlessDemoAppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
	return appDelegate.myJID;
}

- (Service *)serviceWithAddress:(NSString *)addrStr
{
	if (addrStr == nil) return nil;
	
	NSEntityDescription *entity = [NSEntityDescription entityForName:@"Service"
	                                          inManagedObjectContext:[self managedObjectContext]];
	
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"lastResolvedAddress == %@", addrStr];
	
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	[fetchRequest setEntity:entity];
	[fetchRequest setPredicate:predicate];
	[fetchRequest setFetchLimit:1];
	
	NSError *error = nil;
	NSArray *results = [[self managedObjectContext] executeFetchRequest:fetchRequest error:&error];
	
	if (results == nil)
	{
		DDLogError(@"Error searching for service with address \"%@\": %@, %@", addrStr, error, [error userInfo]);
		
		return nil;
	}
	else if ([results count] == 0)
	{
		DDLogWarn(@"Unable to find service with address \"%@\"", addrStr);
		
		return nil;
	}
	else
	{
		return [results objectAtIndex:0];
	}
}

- (id)nextXMPPStreamTag
{
	static NSInteger tag = 0;
	
	NSNumber *result = [NSNumber numberWithInteger:tag];
	tag++;
	
	return result;
}

- (Service *)serviceWithXMPPStream:(XMPPStream *)xmppStream
{
	NSManagedObjectID *managedObjectID = [serviceDict objectForKey:[xmppStream tag]];
	
	return (Service *)[[self managedObjectContext] objectWithID:managedObjectID];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark GCDAsyncSocket Delegate Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)socket:(GCDAsyncSocket *)listenSock didAcceptNewSocket:(GCDAsyncSocket *)acceptedSock
{
	NSString *addrStr = [acceptedSock connectedHost];
	
	Service *service = [self serviceWithAddress:addrStr];
	if (service)
	{
		DDLogInfo(@"Accepting connection from service: %@", service.serviceDescription);
		
		id tag = [self nextXMPPStreamTag];
		
		XMPPStream *xmppStream = [[XMPPStream alloc] initP2PFrom:[self myJID]];
		
		[xmppStream addDelegate:self delegateQueue:dispatch_get_main_queue()];
		xmppStream.tag = tag;
		
		[xmppStream connectP2PWithSocket:acceptedSock error:nil];
		
		[xmppStreams addObject:xmppStream];
		[serviceDict setObject:[service objectID] forKey:tag];
	}
	else
	{
		DDLogWarn(@"Ignoring connection from unknown service (%@)", addrStr);
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStream Delegate Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppStreamDidConnect:(XMPPStream *)sender
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
}

- (void)xmppStream:(XMPPStream *)sender willSendP2PFeatures:(NSXMLElement *)streamFeatures
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
}

- (void)xmppStream:(XMPPStream *)sender didReceiveP2PFeatures:(NSXMLElement *)streamFeatures
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
	
	return NO;
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
	
	Service *service = [self serviceWithXMPPStream:sender];
	if (service)
	{
		NSString *msgBody = [[[message elementForName:@"body"] stringValue] stringByTrimming];
		if ([msgBody length] > 0)
		{
			Message *msg = [NSEntityDescription insertNewObjectForEntityForName:@"Message"
			                                             inManagedObjectContext:[self managedObjectContext]];
			
			msg.content     = msgBody;
			msg.isOutbound  = NO;
			msg.hasBeenRead = NO;
			msg.timeStamp   = [NSDate date];
			
			msg.service     = service;
			
			[[self managedObjectContext] save:nil];
		}
	}
}

- (void)xmppStream:(XMPPStream *)sender didReceivePresence:(XMPPPresence *)presence
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
}

- (void)xmppStream:(XMPPStream *)sender didReceiveError:(id)error
{
	DDLogVerbose(@"%@: %@ %@", THIS_FILE, THIS_METHOD, error);
}

- (void)xmppStreamDidDisconnect:(XMPPStream *)sender withError:(NSError *)error
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
	
	[serviceDict removeObjectForKey:sender.tag];
	[xmppStreams removeObject:sender];
}

@end
