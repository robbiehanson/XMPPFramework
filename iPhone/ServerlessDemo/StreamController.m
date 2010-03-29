#import "StreamController.h"
#import "ServerlessDemoAppDelegate.h"
#import "AsyncSocket.h"
#import "XMPPStream.h"
#import "Service.h"
#import "Message.h"
#import "NSXMLElementAdditions.h"
#import "NSStringAdditions.h"

#define THIS_FILE   @"StreamController"
#define THIS_METHOD NSStringFromSelector(_cmd)


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
		[self release];
		return nil;
	}
	
	if((self = [super init]))
	{
		sockets     = [[NSMutableArray alloc] initWithCapacity:4];
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
		listeningSocket = [[AsyncSocket alloc] initWithDelegate:self];
	}
	
	NSError *error = nil;
	if (![listeningSocket acceptOnPort:0 error:&error])
	{
		NSLog(@"Error setting up socket: %@", error);
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
		NSLog(@"Error searching for service with address \"%@\": %@, %@", addrStr, error, [error userInfo]);
		
		return nil;
	}
	else if ([results count] == 0)
	{
		NSLog(@"Unable to find service with address \"%@\"", addrStr);
		
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
#pragma mark AsyncSocket Delegate Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)onSocket:(AsyncSocket *)sock didAcceptNewSocket:(AsyncSocket *)newSocket
{
	// We don't have access to the socket's connectedAddress yet.
	// Robbie is planning on addressing this shortcoming.
	// 
	// Current Workaround: Wait until the onSocket:didConnectToHost:port: method.
	
	[sockets addObject:newSocket];
}

- (void)onSocket:(AsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port
{
	NSString *addrStr = [sock connectedHost];
	
	Service *service = [self serviceWithAddress:addrStr];
	if (service)
	{
		NSLog(@"Accepting connection from service: %@", service.serviceDescription);
		
		id tag = [self nextXMPPStreamTag];
		
		XMPPStream *xmppStream = [[XMPPStream alloc] initP2PFrom:[self myJID]];
		
		[xmppStream addDelegate:self];
		xmppStream.tag = tag;
		
		[xmppStream connectP2PWithSocket:sock error:nil];
		
		[xmppStreams addObject:xmppStream];
		[serviceDict setObject:[service objectID] forKey:tag];
		
		[sockets removeObject:sock];
	}
	else
	{
		NSLog(@"Ignoring connection from unknown service (%@)", addrStr);
		
		[sock disconnect];
		[sockets removeObject:sock];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStream Delegate Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppStreamDidOpen:(XMPPStream *)sender
{
	NSLog(@"%@: %@", THIS_FILE, THIS_METHOD);
}

- (void)xmppStream:(XMPPStream *)sender willSendP2PFeatures:(NSXMLElement *)streamFeatures
{
	NSLog(@"%@: %@", THIS_FILE, THIS_METHOD);
}

- (void)xmppStream:(XMPPStream *)sender didReceiveP2PFeatures:(NSXMLElement *)streamFeatures
{
	NSLog(@"%@: %@", THIS_FILE, THIS_METHOD);
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
	NSLog(@"%@: %@", THIS_FILE, THIS_METHOD);
	
	return NO;
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
	NSLog(@"%@: %@", THIS_FILE, THIS_METHOD);
	
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
	NSLog(@"%@: %@", THIS_FILE, THIS_METHOD);
}

- (void)xmppStream:(XMPPStream *)sender didReceiveError:(id)error
{
	NSLog(@"%@: %@ %@", THIS_FILE, THIS_METHOD, error);
}

- (void)xmppStreamDidClose:(XMPPStream *)sender
{
	NSLog(@"%@: %@", THIS_FILE, THIS_METHOD);
	
	[serviceDict removeObjectForKey:sender.tag];
	[xmppStreams removeObject:sender];
}

@end
