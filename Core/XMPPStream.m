#import "XMPPStream.h"
#import "XMPPInternal.h"
#import "XMPPParser.h"
#import "XMPPJID.h"
#import "XMPPIQ.h"
#import "XMPPMessage.h"
#import "XMPPPresence.h"
#import "XMPPModule.h"
#import "XMPPLogging.h"
#import "NSData+XMPP.h"
#import "NSXMLElement+XMPP.h"
#import "XMPPDigestAuthentication.h"
#import "XMPPXFacebookPlatformAuthentication.h"
#import "XMPPSRVResolver.h"
#import "DDList.h"

#import <libkern/OSAtomic.h>

#if TARGET_OS_IPHONE
  // Note: You may need to add the CFNetwork Framework to your project
  #import <CFNetwork/CFNetwork.h>
#endif

#if TARGET_OS_IPHONE
  #define SOCKET_BUFFER_SIZE 512  // bytes
#else
  #define SOCKET_BUFFER_SIZE 1024 // bytes
#endif

/**
 * Seeing a return statements within an inner block
 * can sometimes be mistaken for a return point of the enclosing method.
 * This makes inline blocks a bit easier to read.
**/
#define return_from_block  return

// Log levels: off, error, warn, info, verbose
#if DEBUG
  static const int xmppLogLevel = XMPP_LOG_LEVEL_INFO | XMPP_LOG_FLAG_SEND_RECV; // | XMPP_LOG_FLAG_TRACE;
#else
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif


NSString *const XMPPStreamErrorDomain = @"XMPPStreamErrorDomain";
NSString *const XMPPStreamDidChangeMyJIDNotification = @"XMPPStreamDidChangeMyJID";

static NSString *const XMPPFacebookChatHostName = @"chat.facebook.com";


enum XMPPStreamFlags
{
	kP2PInitiator                 = 1 << 0,  // If set, we are the P2P initializer
	kIsSecure                     = 1 << 1,  // If set, connection has been secured via SSL/TLS
	kIsAuthenticated              = 1 << 2,  // If set, authentication has succeeded
	kDidStartNegotiation          = 1 << 3,  // If set, negotiation has started at least once
};

enum XMPPStreamConfig
{
	kP2PMode                      = 1 << 0,  // If set, the XMPPStream was initialized in P2P mode
	kResetByteCountPerConnection  = 1 << 1,  // If set, byte count should be reset per connection
#if TARGET_OS_IPHONE
	kEnableBackgroundingOnSocket  = 1 << 2,  // If set, the VoIP flag should be set on the socket
#endif
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface XMPPStream (PrivateAPI)

- (void)cleanup;
- (void)setIsSecure:(BOOL)flag;
- (void)setIsAuthenticated:(BOOL)flag;
- (void)continueSendElement:(NSXMLElement *)element withTag:(long)tag;
- (void)startNegotiation;
- (void)sendOpeningNegotiation;
- (void)continueStartTLS:(NSMutableDictionary *)settings;
- (void)setupKeepAliveTimer;
- (void)keepAlive;

@end

@interface XMPPElementReceipt (PrivateAPI)

- (void)signalSuccess;
- (void)signalFailure;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPStream

@synthesize tag = userTag;

/**
 * Shared initialization between the various init methods.
**/
- (void)commonInit
{
	xmppQueue = dispatch_queue_create("xmppStreamQueue", NULL);
	parserQueue = dispatch_queue_create("xmppParserQueue", NULL);
	
	multicastDelegate = (GCDMulticastDelegate <XMPPStreamDelegate> *)[[GCDMulticastDelegate alloc] init];
	
	state = STATE_XMPP_DISCONNECTED;
	
	flags = 0;
	config = 0;
	
	numberOfBytesSent = 0;
	numberOfBytesReceived = 0;
	
	parser = [(XMPPParser *)[XMPPParser alloc] initWithDelegate:self];
	
	hostPort = 5222;
	keepAliveInterval = DEFAULT_KEEPALIVE_INTERVAL;
	
	registeredModules = [[DDList alloc] init];
	autoDelegateDict = [[NSMutableDictionary alloc] init];
	
	receipts = [[NSMutableArray alloc] init];
	
	// Setup and start the utility thread.
	// We need to be careful to ensure the thread doesn't retain a reference to us longer than necessary.
	
	xmppUtilityThread = [[NSThread alloc] initWithTarget:[self class] selector:@selector(xmppThreadMain) object:nil];
	[[xmppUtilityThread threadDictionary] setObject:self forKey:@"XMPPStream"];
	[xmppUtilityThread start];
}

/**
 * Standard XMPP initialization.
 * The stream is a standard client to server connection.
**/
- (id)init
{
	if ((self = [super init]))
	{
		// Common initialization
		[self commonInit];
		
		// Initialize socket
		asyncSocket = [(GCDAsyncSocket *)[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:xmppQueue];
	}
	return self;
}

/**
 * Peer to Peer XMPP initialization.
 * The stream is a direct client to client connection as outlined in XEP-0174.
**/
- (id)initP2PFrom:(XMPPJID *)jid
{
    if ((self = [super init]))
    {
		// Common initialization
		[self commonInit];
		
		// Store JID
		myJID = [jid retain];
        
        // We do not initialize the socket, since the connectP2PWithSocket: method might be used.
        
        // Initialize configuration
        config = kP2PMode;
    }
	return self;
}


/**
 * Facebook Chat X-FACEBOOK-PLATFORM SASL authentication initialization.
 * This is a convienence init method to help configure Facebook Chat.
**/
- (id)initWithFacebookAppId:(NSString *)fbAppId 
{
    if ((self = [self init]))
    {
        self.appId = fbAppId;
        self.myJID = [XMPPJID jidWithString:XMPPFacebookChatHostName];
        self.hostName = XMPPFacebookChatHostName;
    }
    return self;
}

/**
 * Standard deallocation method.
 * Every object variable declared in the header file should be released here.
**/
- (void)dealloc
{
	dispatch_release(xmppQueue);
	dispatch_release(parserQueue);
	
	[multicastDelegate release];
	
	[asyncSocket setDelegate:nil delegateQueue:NULL];
	[asyncSocket disconnect];
	[asyncSocket release];
	[socketBuffer release];
	
	[parser setDelegate:nil];
	[parser release];
	[parserError release];
	
	[hostName release];
	
	[tempPassword release];
	
	[myJID release];
	[remoteJID release];
	
	[myPresence release];
	[rootElement release];
	
	if (keepAliveTimer)
	{
		dispatch_source_cancel(keepAliveTimer);
	}
	
	[registeredModules release];
	[autoDelegateDict release];
	
	[srvResolver release];
	[srvResults release];
    
	for (XMPPElementReceipt *receipt in receipts)
	{
		[receipt signalFailure];
	}
    [receipts release];
	
	[[self class] performSelector:@selector(xmppThreadStop)
	                     onThread:xmppUtilityThread
	                   withObject:nil
	                waitUntilDone:NO];
	
	[userTag release];
	
	[super dealloc];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Properties
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSString *)appId
{
	if (dispatch_get_current_queue() == xmppQueue)
	{
		return appId;
	}
	else
	{
		__block NSString *result;
		
		dispatch_sync(xmppQueue, ^{
			result = [appId retain];
		});
		
		return [result autorelease];
	}
}

- (void)setAppId:(NSString *)newAppId
{
	if (dispatch_get_current_queue() == xmppQueue)
	{
		if (appId != newAppId)
		{
			[appId release];
			appId = [newAppId copy];
		}
	}
	else
	{
		NSString *newAppIdCopy = [newAppId copy];
		
		dispatch_async(xmppQueue, ^{
			[appId release];
			appId = [newAppIdCopy retain];
		});
		
		[newAppIdCopy release];
	}
}

- (NSString *)hostName
{
	if (dispatch_get_current_queue() == xmppQueue)
	{
		return hostName;
	}
	else
	{
		__block NSString *result;
		
		dispatch_sync(xmppQueue, ^{
			result = [hostName retain];
		});
		
		return [result autorelease];
	}
}

- (void)setHostName:(NSString *)newHostName
{
	if (dispatch_get_current_queue() == xmppQueue)
	{
		if (hostName != newHostName)
		{
			[hostName release];
			hostName = [newHostName copy];
		}
	}
	else
	{
		NSString *newHostNameCopy = [newHostName copy];
		
		dispatch_async(xmppQueue, ^{
			[hostName release];
			hostName = [newHostNameCopy retain];
		});
		
		[newHostNameCopy release];
	}
}

- (UInt16)hostPort
{
	if (dispatch_get_current_queue() == xmppQueue)
	{
		return hostPort;
	}
	else
	{
		__block UInt16 result;
		
		dispatch_sync(xmppQueue, ^{
			result = hostPort;
		});
		
		return result;
	}
}

- (void)setHostPort:(UInt16)newHostPort
{
	dispatch_block_t block = ^{
		hostPort = newHostPort;
	};
	
	if (dispatch_get_current_queue() == xmppQueue)
		block();
	else
		dispatch_async(xmppQueue, block);
}

- (XMPPJID *)myJID
{
	if (dispatch_get_current_queue() == xmppQueue)
	{
		return myJID;
	}
	else
	{
		__block XMPPJID *result;
		
		dispatch_sync(xmppQueue, ^{
			result = [myJID retain];
		});
		
		return [result autorelease];
	}
}

- (void)setMyJID:(XMPPJID *)newMyJID
{
	// XMPPJID is an immutable class (copy == retain)
	
	dispatch_block_t block = ^{
	
		if (myJID != newMyJID)
		{
			[myJID release];
			myJID = [newMyJID retain];
		}
		
		[[NSNotificationCenter defaultCenter] postNotificationName:XMPPStreamDidChangeMyJIDNotification object:self];
	};
	
	if (dispatch_get_current_queue() == xmppQueue)
		block();
	else
		dispatch_async(xmppQueue, block);
}

- (XMPPJID *)remoteJID
{
	if (dispatch_get_current_queue() == xmppQueue)
	{
		return remoteJID;
	}
	else
	{
		__block XMPPJID *result;
		
		dispatch_sync(xmppQueue, ^{
			result = [remoteJID retain];
		});
		
		return [result autorelease];
	}
}

- (XMPPPresence *)myPresence
{
	if (dispatch_get_current_queue() == xmppQueue)
	{
		return myPresence;
	}
	else
	{
		__block XMPPPresence *result;
		
		dispatch_sync(xmppQueue, ^{
			result = [myPresence retain];
		});
		
		return [result autorelease];
	}
}

- (NSTimeInterval)keepAliveInterval
{
	if (dispatch_get_current_queue() == xmppQueue)
	{
		return keepAliveInterval;
	}
	else
	{
		__block NSTimeInterval result;
		
		dispatch_sync(xmppQueue, ^{
			result = keepAliveInterval;
		});
		
		return result;
	}
}

- (void)setKeepAliveInterval:(NSTimeInterval)interval
{
	dispatch_block_t block = ^{
		
		if (keepAliveInterval != interval)
		{
			if (interval <= 0.0)
				keepAliveInterval = interval;
			else
				keepAliveInterval = MAX(interval, MIN_KEEPALIVE_INTERVAL);
			
			[self setupKeepAliveTimer];
		}
	};
	
	if (dispatch_get_current_queue() == xmppQueue)
		block();
	else
		dispatch_async(xmppQueue, block);
}

- (UInt64)numberOfBytesSent
{
	if (dispatch_get_current_queue() == xmppQueue)
	{
		return numberOfBytesSent;
	}
	else
	{
		__block UInt64 result;
		
		dispatch_sync(xmppQueue, ^{
			result = numberOfBytesSent;
		});
		
		return result;
	}
}

- (UInt64)numberOfBytesReceived
{
	if (dispatch_get_current_queue() == xmppQueue)
	{
		return numberOfBytesReceived;
	}
	else
	{
		__block UInt64 result;
		
		dispatch_sync(xmppQueue, ^{
			result = numberOfBytesReceived;
		});
		
		return result;
	}
}

- (BOOL)resetByteCountPerConnection
{
	__block BOOL result = NO;
	
	dispatch_block_t block = ^{
		result = (config & kResetByteCountPerConnection) ? YES : NO;
	};
	
	if (dispatch_get_current_queue() == xmppQueue)
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	return result;
}

- (void)setResetByteCountPerConnection:(BOOL)flag
{
	dispatch_block_t block = ^{
		if (flag)
			config |= kResetByteCountPerConnection;
		else
			config &= ~kResetByteCountPerConnection;
	};
	
	if (dispatch_get_current_queue() == xmppQueue)
		block();
	else
		dispatch_async(xmppQueue, block);
}

#if TARGET_OS_IPHONE

- (BOOL)enableBackgroundingOnSocket
{
	__block BOOL result = NO;
	
	dispatch_block_t block = ^{
		result = (config & kEnableBackgroundingOnSocket) ? YES : NO;
	};
	
	if (dispatch_get_current_queue() == xmppQueue)
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	return result;
}

- (void)setEnableBackgroundingOnSocket:(BOOL)flag
{
	dispatch_block_t block = ^{
		if (flag)
			config |= kEnableBackgroundingOnSocket;
		else
			config &= ~kEnableBackgroundingOnSocket;
	};
	
	if (dispatch_get_current_queue() == xmppQueue)
		block();
	else
		dispatch_async(xmppQueue, block);
}

#endif

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Configuration
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)addDelegate:(id)delegate delegateQueue:(dispatch_queue_t)delegateQueue
{
	// Asynchronous operation (if outside xmppQueue)
	
	dispatch_block_t block = ^{
		[multicastDelegate addDelegate:delegate delegateQueue:delegateQueue];
	};
	
	if (dispatch_get_current_queue() == xmppQueue)
		block();
	else
		dispatch_async(xmppQueue, block);
}

- (void)removeDelegate:(id)delegate delegateQueue:(dispatch_queue_t)delegateQueue
{
	// Synchronous operation
	
	dispatch_block_t block = ^{
		[multicastDelegate removeDelegate:delegate delegateQueue:delegateQueue];
	};
	
	if (dispatch_get_current_queue() == xmppQueue)
		block();
	else
		dispatch_sync(xmppQueue, block);
}

- (void)removeDelegate:(id)delegate
{
	// Synchronous operation
	
	dispatch_block_t block = ^{
		[multicastDelegate removeDelegate:delegate];
	};
	
	if (dispatch_get_current_queue() == xmppQueue)
		block();
	else
		dispatch_sync(xmppQueue, block);
}

/**
 * Returns YES if the stream was opened in P2P mode.
 * In other words, the stream was created via initP2PFrom: to use XEP-0174.
**/
- (BOOL)isP2P
{
	if (dispatch_get_current_queue() == xmppQueue)
	{
		return (config & kP2PMode) ? YES : NO;
	}
	else
	{
		__block BOOL result;
		
		dispatch_sync(xmppQueue, ^{
			result = (config & kP2PMode) ? YES : NO;
		});
		
		return result;
	}
}

- (BOOL)isP2PInitiator
{
	if (dispatch_get_current_queue() == xmppQueue)
	{
		return ((config & kP2PMode) && (flags & kP2PInitiator));
	}
	else
	{
		__block BOOL result;
		
		dispatch_sync(xmppQueue, ^{
			result = ((config & kP2PMode) && (flags & kP2PInitiator));
		});
		
		return result;
	}
}

- (BOOL)isP2PRecipient
{
	if (dispatch_get_current_queue() == xmppQueue)
	{
		return ((config & kP2PMode) && !(flags & kP2PInitiator));
	}
	else
	{
		__block BOOL result;
		
		dispatch_sync(xmppQueue, ^{
			result = ((config & kP2PMode) && !(flags & kP2PInitiator));
		});
		
		return result;
	}
}

- (BOOL)didStartNegotiation
{
	NSAssert(dispatch_get_current_queue() == xmppQueue, @"Invoked on incorrect queue");
	
	return (flags & kDidStartNegotiation) ? YES : NO;
}

- (void)setDidStartNegotiation:(BOOL)flag
{
	NSAssert(dispatch_get_current_queue() == xmppQueue, @"Invoked on incorrect queue");
	
	if (flag)
		flags |= kDidStartNegotiation;
	else
		flags &= ~kDidStartNegotiation;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Connection State
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Returns YES if the connection is closed, and thus no stream is open.
 * If the stream is neither disconnected, nor connected, then a connection is currently being established.
**/
- (BOOL)isDisconnected
{
	__block BOOL result = NO;
	
	dispatch_block_t block = ^{
		result = (state == STATE_XMPP_DISCONNECTED);
	};
	
	if (dispatch_get_current_queue() == xmppQueue)
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	return result;
}

/**
 * Returns YES if the connection is open, and the stream has been properly established.
 * If the stream is neither disconnected, nor connected, then a connection is currently being established.
**/
- (BOOL)isConnected
{
	__block BOOL result = NO;
	
	dispatch_block_t block = ^{
		result = (state == STATE_XMPP_CONNECTED);
	};
	
	if (dispatch_get_current_queue() == xmppQueue)
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark C2S Connection
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)connectToHost:(NSString *)host onPort:(UInt16)port error:(NSError **)errPtr
{
	NSAssert(dispatch_get_current_queue() == xmppQueue, @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	BOOL result = [asyncSocket connectToHost:host onPort:port error:errPtr];
	
	if (result && [self resetByteCountPerConnection])
	{
		numberOfBytesSent = 0;
		numberOfBytesReceived = 0;
	}
	
	return result;
}

- (BOOL)connect:(NSError **)errPtr
{
	XMPPLogTrace();
	
	__block BOOL result = NO;
	__block NSError *err = nil;
	
	dispatch_block_t block = ^{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
		if (state != STATE_XMPP_DISCONNECTED)
		{
			NSString *errMsg = @"Attempting to connect while already connected or connecting.";
			NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
			
			err = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidState userInfo:info];
			
			[err retain];
			[pool drain];
			
			result = NO;
			return_from_block;
		}
		
		if ([self isP2P])
		{
			NSString *errMsg = @"P2P streams must use either connectTo:withAddress: or connectP2PWithSocket:.";
			NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
			
			err = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidType userInfo:info];
			
			[err retain];
			[pool drain];
			
			result = NO;
			return_from_block;
		}
		
		if (myJID == nil)
		{
			// Note: If you wish to use anonymous authentication, you should still set myJID prior to calling connect.
			// You can simply set it to something like "anonymous@<domain>", where "<domain>" is the proper domain.
			// After the authentication process, you can query the myJID property to see what your assigned JID is.
			// 
			// Setting myJID allows the framework to follow the xmpp protocol properly,
			// and it allows the framework to connect to servers without a DNS entry.
			// 
			// For example, one may setup a private xmpp server for internal testing on their local network.
			// The xmpp domain of the server may be something like "testing.mycompany.com",
			// but since the server is internal, an IP (192.168.1.22) is used as the hostname to connect.
			// 
			// Proper connection requires a TCP connection to the IP (192.168.1.22),
			// but the xmpp handshake requires the xmpp domain (testing.mycompany.com).
			
			NSString *errMsg = @"You must set myJID before calling connect.";
			NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
			
			err = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidProperty userInfo:info];
			
			[err retain];
			[pool drain];
			
			result = NO;
			return_from_block;
		}

		// Notify delegates
		[multicastDelegate xmppStreamWillConnect:self];
        
        // Check for Facebook Chat and set hostName if not set.
        // As of October 8, 2011, Facebook doesn't have their XMPP SRV records configured properly
        // and we have to wait for the SRV timeout before trying the A record.
        if ([hostName length] == 0 && [myJID.domain isEqualToString:XMPPFacebookChatHostName])
        {
            self.hostName = XMPPFacebookChatHostName;
        }

		if ([hostName length] == 0)
		{
			// Resolve the hostName via myJID SRV resolution
			
			state = STATE_XMPP_RESOLVING_SRV;
			
			[srvResolver release];
			srvResolver = [[XMPPSRVResolver alloc] initWithdDelegate:self delegateQueue:xmppQueue resolverQueue:NULL];
			
			[srvResults release];
			srvResults = nil;
			srvResultsIndex = 0;
			
			NSString *srvName = [XMPPSRVResolver srvNameFromXMPPDomain:[myJID domain]];
			
			[srvResolver startWithSRVName:srvName timeout:30.0];
			
			result = YES;
		}
		else
		{
			// Open TCP connection to the configured hostName.
			
			state = STATE_XMPP_CONNECTING;
			
			result = [self connectToHost:hostName onPort:hostPort error:&err];
			
			if (!result)
			{
				state = STATE_XMPP_DISCONNECTED;
			}
		}
		
		[err retain];
		[pool drain];
	};
	
	if (dispatch_get_current_queue() == xmppQueue)
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	if (errPtr)
		*errPtr = [err autorelease];
	else
		[err release];
	
	return result;
}

- (BOOL)oldSchoolSecureConnect:(NSError **)errPtr
{
	XMPPLogTrace();
	
	__block BOOL result = NO;
	__block NSError *err = nil;
	
	dispatch_block_t block = ^{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		// Go through the regular connect routine
		result = [self connect:&err];
		
		if (result)
		{
			// Mark the secure flag.
			// We will check the flag in socket:didConnectToHost:port:
			
			[self setIsSecure:YES];
		}
		
		[err retain];
		[pool drain];
	};
	
	if (dispatch_get_current_queue() == xmppQueue)
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	if (errPtr)
		*errPtr = [err autorelease];
	else
		[err release];
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark P2P Connection
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Starts a P2P connection to the given user and given address.
 * This method only works with XMPPStream objects created using the initP2P method.
 * 
 * The given address is specified as a sockaddr structure wrapped in a NSData object.
 * For example, a NSData object returned from NSNetservice's addresses method.
**/
- (BOOL)connectTo:(XMPPJID *)jid withAddress:(NSData *)remoteAddr error:(NSError **)errPtr
{
	XMPPLogTrace();
	
	__block BOOL result = YES;
	__block NSError *err = nil;
	
	dispatch_block_t block = ^{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		if (state != STATE_XMPP_DISCONNECTED)
		{
			NSString *errMsg = @"Attempting to connect while already connected or connecting.";
			NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
			
			err = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidState userInfo:info];
			
			[err retain];
			[pool drain];
			
			result = NO;
			return_from_block;
		}
		
		if (![self isP2P])
		{
			NSString *errMsg = @"Non P2P streams must use the connect: method";
			NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
			
			err = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidType userInfo:info];
			
			[err retain];
			[pool drain];
			
			result = NO;
			return_from_block;
		}
		
		// Turn on P2P initiator flag
		flags |= kP2PInitiator;
		
		// Store remoteJID
		[remoteJID release];
		remoteJID = [jid copy];
		
		NSAssert((asyncSocket == nil), @"Forgot to release the previous asyncSocket instance.");

		// Notify delegates
		[multicastDelegate xmppStreamWillConnect:self];

		// Update state
		state = STATE_XMPP_CONNECTING;
		
		// Initailize socket
		asyncSocket = [(GCDAsyncSocket *)[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:xmppQueue];
		
		result = [asyncSocket connectToAddress:remoteAddr error:&err];
		
		if (result == NO)
		{
			state = STATE_XMPP_DISCONNECTED;
		}
		else if ([self resetByteCountPerConnection])
		{
			numberOfBytesSent = 0;
			numberOfBytesReceived = 0;
		}
		
		[err retain];
		[pool drain];
	};
	
	if (dispatch_get_current_queue() == xmppQueue)
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	if (errPtr)
		*errPtr = [err autorelease];
	else
		[err release];
	
	return result;
}

/**
 * Starts a P2P connection with the given accepted socket.
 * This method only works with XMPPStream objects created using the initP2P method.
 * 
 * The given socket should be a socket that has already been accepted.
 * The remoteJID will be extracted from the opening stream negotiation.
**/
- (BOOL)connectP2PWithSocket:(GCDAsyncSocket *)acceptedSocket error:(NSError **)errPtr
{
	XMPPLogTrace();
	
	__block BOOL result = YES;
	__block NSError *err = nil;
	
	dispatch_block_t block = ^{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		if (state != STATE_XMPP_DISCONNECTED)
		{
			NSString *errMsg = @"Attempting to connect while already connected or connecting.";
			NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
			
			err = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidState userInfo:info];
			
			[err retain];
			[pool drain];
			
			result = NO;
			return_from_block;
		}
		
		if (![self isP2P])
		{
			NSString *errMsg = @"Non P2P streams must use the connect: method";
			NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
			
			err = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidType userInfo:info];
			
			[err retain];
			[pool drain];
			
			result = NO;
			return_from_block;
		}
		
		if (acceptedSocket == nil)
		{
			NSString *errMsg = @"Parameter acceptedSocket is nil.";
			NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
			
			err = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidParameter userInfo:info];
			
			[err retain];
			[pool drain];
			
			result = NO;
			return_from_block;
		}
		
		// Turn off P2P initiator flag
		flags &= ~kP2PInitiator;
		
		NSAssert((asyncSocket == nil), @"Forgot to release the previous asyncSocket instance.");
		
		// Store and configure socket
		asyncSocket = [acceptedSocket retain];
		[asyncSocket setDelegate:self delegateQueue:xmppQueue];
		
		// Notify delegates
		[multicastDelegate xmppStream:self socketDidConnect:asyncSocket];

		// Update state
		state = STATE_XMPP_CONNECTING;
		
		if ([self resetByteCountPerConnection])
		{
			numberOfBytesSent = 0;
			numberOfBytesReceived = 0;
		}
		
		// Start the XML stream
		[self startNegotiation];
		
		[err retain];
		[pool drain];
	};
	
	if (dispatch_get_current_queue() == xmppQueue)
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	if (errPtr)
		*errPtr = [err autorelease];
	else
		[err release];
	
    return result;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Disconnect
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Closes the connection to the remote host.
**/
- (void)disconnect
{
	XMPPLogTrace();
	
	dispatch_block_t block = ^{
		
		if (state != STATE_XMPP_DISCONNECTED)
		{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			
			[multicastDelegate xmppStreamWasToldToDisconnect:self];
			
			if (state == STATE_XMPP_RESOLVING_SRV)
			{
				[srvResolver stop];
				[srvResolver release];
				srvResolver = nil;
				
				state = STATE_XMPP_DISCONNECTED;
				
				[multicastDelegate xmppStreamDidDisconnect:self withError:nil];
			}
			else
			{
				[asyncSocket disconnect];
				
				// Everthing will be handled in socketDidDisconnect:withError:
			}
			
			[pool drain];
		}
	};
	
	if (dispatch_get_current_queue() == xmppQueue)
		block();
	else
		dispatch_sync(xmppQueue, block);
}

- (void)disconnectAfterSending
{
	XMPPLogTrace();
	
	dispatch_block_t block = ^{
		
		if (state != STATE_XMPP_DISCONNECTED)
		{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			
			[multicastDelegate xmppStreamWasToldToDisconnect:self];
			
			if (state == STATE_XMPP_RESOLVING_SRV)
			{
				[srvResolver stop];
				[srvResolver release];
				srvResolver = nil;
				
				state = STATE_XMPP_DISCONNECTED;
				
				[multicastDelegate xmppStreamDidDisconnect:self withError:nil];
			}
			else
			{
				[asyncSocket disconnectAfterWriting];
				
				// Everthing will be handled in socketDidDisconnect:withError:
			}
			
			[pool drain];
		}
	};
	
	if (dispatch_get_current_queue() == xmppQueue)
		block();
	else
		dispatch_async(xmppQueue, block);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Security
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Returns YES if SSL/TLS has been used to secure the connection.
**/
- (BOOL)isSecure
{
	if (dispatch_get_current_queue() == xmppQueue)
	{
		return (flags & kIsSecure) ? YES : NO;
	}
	else
	{
		__block BOOL result;
		
		dispatch_sync(xmppQueue, ^{
			result = (flags & kIsSecure) ? YES : NO;
		});
		
		return result;
	}
}

- (void)setIsSecure:(BOOL)flag
{
	dispatch_block_t block = ^{
		if(flag)
			flags |= kIsSecure;
		else
			flags &= ~kIsSecure;
	};
	
	if (dispatch_get_current_queue() == xmppQueue)
		block();
	else
		dispatch_async(xmppQueue, block);
}

- (BOOL)supportsStartTLS
{
	__block BOOL result = NO;
	
	dispatch_block_t block = ^{
		
		// The root element can be properly queried for authentication mechanisms anytime after the
		//stream:features are received, and TLS has been setup (if required)
		if (state >= STATE_XMPP_POST_NEGOTIATION)
		{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			
			NSXMLElement *features = [rootElement elementForName:@"stream:features"];
			NSXMLElement *starttls = [features elementForName:@"starttls" xmlns:@"urn:ietf:params:xml:ns:xmpp-tls"];
			
			result = (starttls != nil);
			
			[pool drain];
		}
	};
	
	if (dispatch_get_current_queue() == xmppQueue)
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	return result;
}

- (void)sendSASLRequestForMechanism:(NSString *)mechanism
{
  NSString *auth = [NSString stringWithFormat:@"<auth xmlns='urn:ietf:params:xml:ns:xmpp-sasl' mechanism='%@'/>", mechanism];
  
  NSData *outgoingData = [auth dataUsingEncoding:NSUTF8StringEncoding];
  
  XMPPLogSend(@"SEND: %@", auth);
  numberOfBytesSent += [outgoingData length];
  
  [asyncSocket writeData:outgoingData
             withTimeout:TIMEOUT_XMPP_WRITE
                     tag:TAG_XMPP_WRITE_STREAM];
}

- (void)sendStartTLSRequest
{
	NSAssert(dispatch_get_current_queue() == xmppQueue, @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	NSString *starttls = @"<starttls xmlns='urn:ietf:params:xml:ns:xmpp-tls'/>";
	
	NSData *outgoingData = [starttls dataUsingEncoding:NSUTF8StringEncoding];
	
	XMPPLogSend(@"SEND: %@", starttls);
	numberOfBytesSent += [outgoingData length];
	
	[asyncSocket writeData:outgoingData
			   withTimeout:TIMEOUT_XMPP_WRITE
					   tag:TAG_XMPP_WRITE_STREAM];
}

- (BOOL)secureConnection:(NSError **)errPtr
{
	XMPPLogTrace();
	
	__block BOOL result = YES;
	__block NSError *err = nil;
	
	dispatch_block_t block = ^{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		if (state != STATE_XMPP_CONNECTED)
		{
			NSString *errMsg = @"Please wait until the stream is connected.";
			NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
			
			err = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidState userInfo:info];
			
			[err retain];
			[pool drain];
			
			result = NO;
			return_from_block;
		}
		
		if (![self supportsStartTLS])
		{
			NSString *errMsg = @"The server does not support startTLS.";
			NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
			
			err = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamUnsupportedAction userInfo:info];
			
			[err retain];
			[pool drain];
			
			result = NO;
			return_from_block;
		}
		
		// Update state
		state = STATE_XMPP_STARTTLS_1;
		
		// Send the startTLS XML request
		[self sendStartTLSRequest];
		
		// We do not mark the stream as secure yet.
		// We're waiting to receive the <proceed/> response from the
		// server before we actually start the TLS handshake.
		
		[pool drain];
	};
	
	if (dispatch_get_current_queue() == xmppQueue)
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	if (errPtr)
		*errPtr = [err autorelease];
	else
		[err release];
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Registration
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method checks the stream features of the connected server to determine if in-band registartion is supported.
 * If we are not connected to a server, this method simply returns NO.
**/
- (BOOL)supportsInBandRegistration
{
	__block BOOL result = NO;
	
	dispatch_block_t block = ^{
		
		// The root element can be properly queried for authentication mechanisms anytime after the
		// stream:features are received, and TLS has been setup (if required)
		if (state >= STATE_XMPP_POST_NEGOTIATION)
		{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			
			NSXMLElement *features = [rootElement elementForName:@"stream:features"];
			NSXMLElement *reg = [features elementForName:@"register" xmlns:@"http://jabber.org/features/iq-register"];
			
			result = (reg != nil);
			
			[pool drain];
		}
	};
	
	if (dispatch_get_current_queue() == xmppQueue)
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	return result;
}

/**
 * This method attempts to register a new user on the server using the given username and password.
 * The result of this action will be returned via the delegate methods.
 * 
 * If the XMPPStream is not connected, or the server doesn't support in-band registration, this method does nothing.
**/
- (BOOL)registerWithPassword:(NSString *)password error:(NSError **)errPtr
{
	XMPPLogTrace();
	
	__block BOOL result = YES;
	__block NSError *err = nil;
	
	dispatch_block_t block = ^{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		if (state != STATE_XMPP_CONNECTED)
		{
			NSString *errMsg = @"Please wait until the stream is connected.";
			NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
			
			err = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidState userInfo:info];
			
			[err retain];
			[pool drain];
			
			result = NO;
			return_from_block;
		}
		
		if (myJID == nil)
		{
			NSString *errMsg = @"You must set myJID before calling registerWithPassword:error:.";
			NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
			
			err = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidProperty userInfo:info];
			
			[err retain];
			[pool drain];
			
			result = NO;
			return_from_block;
		}
		
		if (![self supportsInBandRegistration])
		{
			NSString *errMsg = @"The server does not support in band registration.";
			NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
			
			err = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamUnsupportedAction userInfo:info];
			
			[err retain];
			[pool drain];
			
			result = NO;
			return_from_block;
		}
		
		NSString *username = [myJID user];
		
		NSXMLElement *queryElement = [NSXMLElement elementWithName:@"query" xmlns:@"jabber:iq:register"];
		[queryElement addChild:[NSXMLElement elementWithName:@"username" stringValue:username]];
		[queryElement addChild:[NSXMLElement elementWithName:@"password" stringValue:password]];
		
		NSXMLElement *iqElement = [NSXMLElement elementWithName:@"iq"];
		[iqElement addAttributeWithName:@"type" stringValue:@"set"];
		[iqElement addChild:queryElement];
		
		NSString *outgoingStr = [iqElement compactXMLString];
		NSData *outgoingData = [outgoingStr dataUsingEncoding:NSUTF8StringEncoding];
		
		XMPPLogSend(@"SEND: %@", outgoingStr);
		numberOfBytesSent += [outgoingData length];
		
		[asyncSocket writeData:outgoingData
		           withTimeout:TIMEOUT_XMPP_WRITE
		                   tag:TAG_XMPP_WRITE_STREAM];
		
		// Update state
		state = STATE_XMPP_REGISTERING;
		
		[pool drain];
	};
	
	if (dispatch_get_current_queue() == xmppQueue)
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	if (errPtr)
		*errPtr = [err autorelease];
	else
		[err release];
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Authentication
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method checks the stream features of the connected server to determine if SASL Anonymous Authentication (XEP-0175)
 * is supported. If we are not connected to a server, this method simply returns NO.
 **/
- (BOOL)supportsAnonymousAuthentication
{
	__block BOOL result = NO;
	
	dispatch_block_t block = ^{
		
		// The root element can be properly queried for authentication mechanisms anytime after the
		// stream:features are received, and TLS has been setup (if required)
		if (state >= STATE_XMPP_POST_NEGOTIATION)
		{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			
			NSXMLElement *features = [rootElement elementForName:@"stream:features"];
			NSXMLElement *mech = [features elementForName:@"mechanisms" xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
			
			NSArray *mechanisms = [mech elementsForName:@"mechanism"];
			
			for (NSXMLElement *mechanism in mechanisms)
			{
				if ([[mechanism stringValue] isEqualToString:@"ANONYMOUS"])
				{
					result = YES;
					break;
				}
			}
			
			[pool drain];
		}
	};
	
	if (dispatch_get_current_queue() == xmppQueue)
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	return result;
}

/**
 * This method checks the stream features of the connected server to determine if plain authentication is supported.
 * If we are not connected to a server, this method simply returns NO.
**/
- (BOOL)supportsPlainAuthentication
{
	__block BOOL result = NO;
	
	dispatch_block_t block = ^{
		
		// The root element can be properly queried for authentication mechanisms anytime after the
		//stream:features are received, and TLS has been setup (if required)
		if (state >= STATE_XMPP_POST_NEGOTIATION)
		{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			
			NSXMLElement *features = [rootElement elementForName:@"stream:features"];
			NSXMLElement *mech = [features elementForName:@"mechanisms" xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
			
			NSArray *mechanisms = [mech elementsForName:@"mechanism"];
			
			for (NSXMLElement *mechanism in mechanisms)
			{
				if ([[mechanism stringValue] isEqualToString:@"PLAIN"])
				{
					result = YES;
					break;
				}
			}
			
			[pool release];
		}
	};
	
	if (dispatch_get_current_queue() == xmppQueue)
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	return result;
}

/**
 * This method checks the stream features of the connected server to determine if digest authentication is supported.
 * If we are not connected to a server, this method simply returns NO.
 * 
 * This is the preferred authentication technique, and will be used if the server supports it.
**/
- (BOOL)supportsDigestMD5Authentication
{
	__block BOOL result = NO;
	
	dispatch_block_t block = ^{
		
		// The root element can be properly queried for authentication mechanisms anytime after the
		// stream:features are received, and TLS has been setup (if required)
		if (state >= STATE_XMPP_POST_NEGOTIATION)
		{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			
			NSXMLElement *features = [rootElement elementForName:@"stream:features"];
			NSXMLElement *mech = [features elementForName:@"mechanisms" xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
			
			NSArray *mechanisms = [mech elementsForName:@"mechanism"];
			
			for (NSXMLElement *mechanism in mechanisms)
			{
				if ([[mechanism stringValue] isEqualToString:@"DIGEST-MD5"])
				{
					result = YES;
					break;
				}
			}
			
			[pool drain];
		}
	};
	
	if (dispatch_get_current_queue() == xmppQueue)
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	return result;
}

/**
 * This method checks the stream features of the connected server to
 * determine if X-FACEBOOK-PLATFORM authentication is supported.
 * If we are not connected to a server, this method simply returns NO.
 **/
- (BOOL)supportsXFacebookPlatformAuthentication
{
	__block BOOL result = NO;
	
	dispatch_block_t block = ^{
		
		// The root element can be properly queried for authentication mechanisms anytime after the
		// stream:features are received, and TLS has been setup (if required)
		if (state >= STATE_XMPP_POST_NEGOTIATION)
		{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			
			NSXMLElement *features = [rootElement elementForName:@"stream:features"];
			NSXMLElement *mech = [features elementForName:@"mechanisms" xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
			
			NSArray *mechanisms = [mech elementsForName:@"mechanism"];
			
			for (NSXMLElement *mechanism in mechanisms)
			{
				if ([[mechanism stringValue] isEqualToString:@"X-FACEBOOK-PLATFORM"])
				{
					result = YES;
					break;
				}
			}
			
			[pool drain];
		}
	};
	
	if (dispatch_get_current_queue() == xmppQueue)
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	return result;
}

/**
 * This method only applies to servers that don't support XMPP version 1.0, as defined in RFC 3920.
 * With these servers, we attempt to discover supported authentication modes via the jabber:iq:auth namespace.
**/
- (BOOL)supportsDeprecatedPlainAuthentication
{
	__block BOOL result = NO;
	
	dispatch_block_t block = ^{
		
		// The root element can be properly queried for authentication mechanisms anytime after the
		// stream:features are received, and TLS has been setup (if required)
		if (state >= STATE_XMPP_POST_NEGOTIATION)
		{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			
			// Search for an iq element within the rootElement.
			// Recall that some servers might stupidly add a "jabber:client" namespace which might cause problems
			// if we simply used the elementForName method.
			
			NSXMLElement *iq = nil;
			
			NSUInteger i, count = [rootElement childCount];
			for (i = 0; i < count; i++)
			{
				NSXMLNode *childNode = [rootElement childAtIndex:i];
				
				if ([childNode kind] == NSXMLElementKind)
				{
					if ([[childNode name] isEqualToString:@"iq"])
					{
						iq = (NSXMLElement *)childNode;
					}
				}
			}
			
			NSXMLElement *query = [iq elementForName:@"query" xmlns:@"jabber:iq:auth"];
			NSXMLElement *plain = [query elementForName:@"password"];
			
			result = (plain != nil);
			
			[pool drain];
		}
	};
	
	if (dispatch_get_current_queue() == xmppQueue)
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	return result;
}

/**
 * This method only applies to servers that don't support XMPP version 1.0, as defined in RFC 3920.
 * With these servers, we attempt to discover supported authentication modes via the jabber:iq:auth namespace.
**/
- (BOOL)supportsDeprecatedDigestAuthentication
{
	__block BOOL result = NO;
	
	dispatch_block_t block = ^{
		
		// The root element can be properly queried for authentication mechanisms anytime after the
		// stream:features are received, and TLS has been setup (if required)
		if (state >= STATE_XMPP_POST_NEGOTIATION)
		{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			
			// Search for an iq element within the rootElement.
			// Recall that some servers might stupidly add a "jabber:client" namespace which might cause problems
			// if we simply used the elementForName method.
			
			NSXMLElement *iq = nil;
			
			NSUInteger i, count = [rootElement childCount];
			for (i = 0; i < count; i++)
			{
				NSXMLNode *childNode = [rootElement childAtIndex:i];
				
				if ([childNode kind] == NSXMLElementKind)
				{
					if ([[childNode name] isEqualToString:@"iq"])
					{
						iq = (NSXMLElement *)childNode;
					}
				}
			}
			
			NSXMLElement *query = [iq elementForName:@"query" xmlns:@"jabber:iq:auth"];
			NSXMLElement *digest = [query elementForName:@"digest"];
			
			result = (digest != nil);
			
			[pool drain];
		}
	};
	
	if (dispatch_get_current_queue() == xmppQueue)
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	return result;
}

/**
 * This method attempts to connect to the Facebook Chat servers 
 * using the Facebook OAuth token returned by the Facebook OAuth 2.0 authentication process.
**/
- (BOOL)authenticateWithFacebookAccessToken:(NSString *)accessToken error:(NSError **)errPtr
{
	XMPPLogTrace();
	
	__block BOOL result = YES;
	__block NSError *err = nil;
	
	dispatch_block_t block = ^{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
				
    if (![self supportsXFacebookPlatformAuthentication])
    {
      NSString *errMsg = @"The server does not support X-FACEBOOK-PLATFORM authentication.";
      NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
      
      err = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamUnsupportedAction userInfo:info];
      
      [err retain];
      [pool drain];
      
      result = NO;
      return_from_block;
    }
    
    // Save authentication information
    isAccessToken = YES;
    [tempPassword release];
    tempPassword = [accessToken copy];

    result = [self authenticateWithPassword:accessToken error:&err];
    
		[err retain];
		[pool drain];
	};
	
	
	if (dispatch_get_current_queue() == xmppQueue)
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	if (errPtr)
		*errPtr = [err autorelease];
	else
		[err release];
	
	return result;
}

/**
 * This method attempts to sign-in to the server using the configured myJID and given password.
 * This method also works with Facebook Chat and the Facebook user's password, but authenticating
 * with authenticateWithFacebookAccessToken:error: is preferred by Facebook.
**/
- (BOOL)authenticateWithPassword:(NSString *)password error:(NSError **)errPtr
{
	XMPPLogTrace();
	
	__block BOOL result = YES;
	__block NSError *err = nil;
	
	dispatch_block_t block = ^{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		if (state != STATE_XMPP_CONNECTED)
		{
			NSString *errMsg = @"Please wait until the stream is connected.";
			NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
			
			err = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidState userInfo:info];
			
			[err retain];
			[pool drain];
			
			result = NO;
			return_from_block;
		}
		
		if (myJID == nil)
		{
			NSString *errMsg = @"You must set myJID before calling authenticateWithPassword:error:.";
			NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
			
			err = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidProperty userInfo:info];
			
			[err retain];
			[pool drain];
			
			result = NO;
			return_from_block;
		}
		
        // Facebook authentication
        if (isAccessToken)
        {
            [self sendSASLRequestForMechanism:@"X-FACEBOOK-PLATFORM"];
      			
			// Update state
			state = STATE_XMPP_AUTH_1;
		} 
        else if ([self supportsDigestMD5Authentication])
		{
            [self sendSASLRequestForMechanism:@"DIGEST-MD5"];
			
			// Save authentication information
            isAccessToken = NO;
			[tempPassword release];
			tempPassword = [password copy];
			
			// Update state
			state = STATE_XMPP_AUTH_1;
		}
		else if ([self supportsPlainAuthentication])
		{
			// From RFC 4616 - PLAIN SASL Mechanism:
			// [authzid] UTF8NUL authcid UTF8NUL passwd
			// 
			// authzid: authorization identity
			// authcid: authentication identity (username)
			// passwd : password for authcid
			
			NSString *username = [myJID user];
			
			NSString *payload = [NSString stringWithFormat:@"%C%@%C%@", 0, username, 0, password];
			NSString *base64 = [[payload dataUsingEncoding:NSUTF8StringEncoding] base64Encoded];
			
			NSXMLElement *auth = [NSXMLElement elementWithName:@"auth" xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
			[auth addAttributeWithName:@"mechanism" stringValue:@"PLAIN"];
			[auth setStringValue:base64];
			
			NSString *outgoingStr = [auth compactXMLString];
			NSData *outgoingData = [outgoingStr dataUsingEncoding:NSUTF8StringEncoding];
			
			XMPPLogSend(@"SEND: %@", outgoingStr);
			numberOfBytesSent += [outgoingData length];
			
			[asyncSocket writeData:outgoingData
					   withTimeout:TIMEOUT_XMPP_WRITE
							   tag:TAG_XMPP_WRITE_STREAM];
			
			// Update state
			state = STATE_XMPP_AUTH_1;
		}
		else
		{
			// The server does not appear to support SASL authentication (at least any type we can use)
			// So we'll revert back to the old fashioned jabber:iq:auth mechanism
			
			NSString *username = [myJID user];
			NSString *resource = [myJID resource];
			
			if ([resource length] == 0)
			{
				// If resource is nil or empty, we need to auto-create one
				
				resource = [self generateUUID];
			}
			
			NSXMLElement *queryElement = [NSXMLElement elementWithName:@"query" xmlns:@"jabber:iq:auth"];
			[queryElement addChild:[NSXMLElement elementWithName:@"username" stringValue:username]];
			[queryElement addChild:[NSXMLElement elementWithName:@"resource" stringValue:resource]];
			
			if ([self supportsDeprecatedDigestAuthentication])
			{
				NSString *rootID = [[[self rootElement] attributeForName:@"id"] stringValue];
				NSString *digestStr = [NSString stringWithFormat:@"%@%@", rootID, password];
				NSData *digestData = [digestStr dataUsingEncoding:NSUTF8StringEncoding];
				
				NSString *digest = [[digestData sha1Digest] hexStringValue];
				
				[queryElement addChild:[NSXMLElement elementWithName:@"digest" stringValue:digest]];
			}
			else
			{
				[queryElement addChild:[NSXMLElement elementWithName:@"password" stringValue:password]];
			}
			
			NSXMLElement *iqElement = [NSXMLElement elementWithName:@"iq"];
			[iqElement addAttributeWithName:@"type" stringValue:@"set"];
			[iqElement addChild:queryElement];
			
			NSString *outgoingStr = [iqElement compactXMLString];
			NSData *outgoingData = [outgoingStr dataUsingEncoding:NSUTF8StringEncoding];
			
			XMPPLogSend(@"SEND: %@", outgoingStr);
			numberOfBytesSent += [outgoingData length];
			
			[asyncSocket writeData:outgoingData
					   withTimeout:TIMEOUT_XMPP_WRITE
							   tag:TAG_XMPP_WRITE_STREAM];
			
			// Update state
			state = STATE_XMPP_AUTH_1;
		}
		
		[err retain];
		[pool drain];
	};
	
	
	if (dispatch_get_current_queue() == xmppQueue)
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	if (errPtr)
		*errPtr = [err autorelease];
	else
		[err release];
	
	return result;
}

/**
 * This method attempts to sign-in to the using SASL Anonymous Authentication (XEP-0175)
**/
- (BOOL)authenticateAnonymously:(NSError **)errPtr
{
	XMPPLogTrace();
	
	__block BOOL result = YES;
	__block NSError *err = nil;
	
	dispatch_block_t block = ^{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		if (state != STATE_XMPP_CONNECTED)
		{
			NSString *errMsg = @"Please wait until the stream is connected.";
			NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
			
			err = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidState userInfo:info];
			
			[err retain];
			[pool drain];
			
			result = NO;
			return_from_block;
		}
		
		if (![self supportsAnonymousAuthentication])
		{
			NSString *errMsg = @"The server does not support anonymous authentication.";
			NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
			
			err = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamUnsupportedAction userInfo:info];
			
			[err retain];
			[pool drain];
			
			result = NO;
			return_from_block;
		}
		
		NSXMLElement *auth = [NSXMLElement elementWithName:@"auth" xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
		[auth addAttributeWithName:@"mechanism" stringValue:@"ANONYMOUS"];
		
		NSString *outgoingStr = [auth compactXMLString];
		NSData *outgoingData = [outgoingStr dataUsingEncoding:NSUTF8StringEncoding];
		
		XMPPLogSend(@"SEND: %@", outgoingStr);
		numberOfBytesSent += [outgoingData length];
		
		[asyncSocket writeData:outgoingData
				   withTimeout:TIMEOUT_XMPP_WRITE
						   tag:TAG_XMPP_WRITE_STREAM];
		
    isAccessToken = NO;
    
		// Update state
		state = STATE_XMPP_AUTH_3;
		
		[err retain];
		[pool drain];
	};
	
	if (dispatch_get_current_queue() == xmppQueue)
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	if (errPtr)
		*errPtr = [err autorelease];
	else
		[err release];
	
	return result;
}

- (BOOL)isAuthenticated
{
	if (dispatch_get_current_queue() == xmppQueue)
	{
		return (flags & kIsAuthenticated) ? YES : NO;
	}
	else
	{
		__block BOOL result;
		
		dispatch_sync(xmppQueue, ^{
			result = (flags & kIsAuthenticated) ? YES : NO;
		});
		
		return result;
	}
}

- (void)setIsAuthenticated:(BOOL)flag
{
	dispatch_block_t block = ^{
		if(flag)
			flags |= kIsAuthenticated;
		else
			flags &= ~kIsAuthenticated;
	};
	
	if (dispatch_get_current_queue() == xmppQueue)
		block();
	else
		dispatch_async(xmppQueue, block);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark General Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method will return the root element of the document.
 * This element contains the opening <stream:stream/> and <stream:features/> tags received from the server
 * when the XML stream was opened.
 * 
 * Note: The rootElement is empty, and does not contain all the XML elements the stream has received during it's
 * connection.  This is done for performance reasons and for the obvious benefit of being more memory efficient.
**/
- (NSXMLElement *)rootElement
{
	if (dispatch_get_current_queue() == xmppQueue)
	{
		return rootElement;
	}
	else
	{
		__block NSXMLElement *result = nil;
		
		dispatch_sync(xmppQueue, ^{
			result = [rootElement copy];
		});
		
		return [result autorelease];
	}
}

/**
 * Returns the version attribute from the servers's <stream:stream/> element.
 * This should be at least 1.0 to be RFC 3920 compliant.
 * If no version number was set, the server is not RFC compliant, and 0 is returned.
**/
- (float)serverXmppStreamVersionNumber
{
	if (dispatch_get_current_queue() == xmppQueue)
	{
		return [rootElement attributeFloatValueForName:@"version" withDefaultValue:0.0F];
	}
	else
	{
		__block float result;
		
		dispatch_sync(xmppQueue, ^{
			result = [rootElement attributeFloatValueForName:@"version" withDefaultValue:0.0F];
		});
		
		return result;
	}
}

- (void)sendIQ:(XMPPIQ *)iq withTag:(long)tag
{
	NSAssert(dispatch_get_current_queue() == xmppQueue, @"Invoked on incorrect queue");
	NSAssert(state == STATE_XMPP_CONNECTED, @"Invoked with incorrect state");
	
	
	// We're getting ready to send an IQ.
	// We need to notify delegates of this action to allow them to optionally alter the IQ element.
	
	SEL selector = @selector(xmppStream:willSendIQ:);
	
	if ([multicastDelegate countForSelector:selector] == 0)
	{
		// None of the delegates implement the method.
		// Use a shortcut.
		
		[self continueSendElement:iq withTag:tag];
	}
	else
	{
		// Notify all interested delegates.
		// This must be done serially to allow them to alter the element.
		
		GCDMulticastDelegateEnumerator *delegateEnumerator = [multicastDelegate delegateEnumerator];
		
		dispatch_queue_t concurrentQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
		dispatch_async(concurrentQueue, ^{
			NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
			
			// Allow delegates to modify outgoing element
			
			id del;
			dispatch_queue_t dq;
			
			while ([delegateEnumerator getNextDelegate:&del delegateQueue:&dq forSelector:selector])
			{
				dispatch_sync(dq, ^{
					NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
					
					[del xmppStream:self willSendIQ:iq];
					
					[innerPool release];
				});
			}
			
			dispatch_async(xmppQueue, ^{
				NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
				
				[self continueSendElement:iq withTag:tag];
				
				[innerPool release];
			});
			
			[outerPool drain];
		});
	}
}

- (void)sendMessage:(XMPPMessage *)message withTag:(long)tag
{
	NSAssert(dispatch_get_current_queue() == xmppQueue, @"Invoked on incorrect queue");
	NSAssert(state == STATE_XMPP_CONNECTED, @"Invoked with incorrect state");
	
	
	// We're getting ready to send a message.
	// We need to notify delegates of this action to allow them to optionally alter the message element.
	
	SEL selector = @selector(xmppStream:willSendMessage:);
	
	if ([multicastDelegate countForSelector:selector] == 0)
	{
		// None of the delegates implement the method.
		// Use a shortcut.
		
		[self continueSendElement:message withTag:tag];
	}
	else
	{
		// Notify all interested delegates.
		// This must be done serially to allow them to alter the element.
		
		GCDMulticastDelegateEnumerator *delegateEnumerator = [multicastDelegate delegateEnumerator];
		
		dispatch_queue_t concurrentQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
		dispatch_async(concurrentQueue, ^{
			NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
			
			// Allow delegates to modify outgoing element
			
			id del;
			dispatch_queue_t dq;
			
			while ([delegateEnumerator getNextDelegate:&del delegateQueue:&dq forSelector:selector])
			{
				dispatch_sync(dq, ^{
					NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
					
					[del xmppStream:self willSendMessage:message];
					
					[innerPool release];
				});
			}
			
			dispatch_async(xmppQueue, ^{
				NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
				
				[self continueSendElement:message withTag:tag];
				
				[innerPool release];
			});
			
			[outerPool drain];
		});
	}
}

- (void)sendPresence:(XMPPPresence *)presence withTag:(long)tag
{
	NSAssert(dispatch_get_current_queue() == xmppQueue, @"Invoked on incorrect queue");
	NSAssert(state == STATE_XMPP_CONNECTED, @"Invoked with incorrect state");
	
	
	// We're getting ready to send a presence element.
	// We need to notify delegates of this action to allow them to optionally alter the presence element.
	
	SEL selector = @selector(xmppStream:willSendPresence:);
	
	if ([multicastDelegate countForSelector:selector] == 0)
	{
		// None of the delegates implement the method.
		// Use a shortcut.
		
		[self continueSendElement:presence withTag:tag];
	}
	else
	{
		// Notify all interested delegates.
		// This must be done serially to allow them to alter the element in a thread-safe manner.
		
		GCDMulticastDelegateEnumerator *delegateEnumerator = [multicastDelegate delegateEnumerator];
		
		dispatch_queue_t concurrentQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
		dispatch_async(concurrentQueue, ^{
			NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
			
			// Allow delegates to modify outgoing element
			
			id del;
			dispatch_queue_t dq;
			
			while ([delegateEnumerator getNextDelegate:&del delegateQueue:&dq forSelector:selector])
			{
				dispatch_sync(dq, ^{
					NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
					
					[del xmppStream:self willSendPresence:presence];
					
					[innerPool release];
				});
			}
			
			dispatch_async(xmppQueue, ^{
				NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
				
				[self continueSendElement:presence withTag:tag];
				
				[innerPool release];
			});
			
			[outerPool drain];
		});
	}
}

- (void)continueSendElement:(NSXMLElement *)element withTag:(long)tag
{
	NSAssert(dispatch_get_current_queue() == xmppQueue, @"Invoked on incorrect queue");
	
	if (state == STATE_XMPP_CONNECTED)
	{
		NSString *outgoingStr = [element compactXMLString];
		NSData *outgoingData = [outgoingStr dataUsingEncoding:NSUTF8StringEncoding];
		
		XMPPLogSend(@"SEND: %@", outgoingStr);
		numberOfBytesSent += [outgoingData length];
		
		[asyncSocket writeData:outgoingData
		           withTimeout:TIMEOUT_XMPP_WRITE
		                   tag:tag];
		
		if ([element isKindOfClass:[XMPPIQ class]])
		{
			[multicastDelegate xmppStream:self didSendIQ:(XMPPIQ *)element];
		}
		else if ([element isKindOfClass:[XMPPMessage class]])
		{
			[multicastDelegate xmppStream:self didSendMessage:(XMPPMessage *)element];
		}
		else if ([element isKindOfClass:[XMPPPresence class]])
		{
			// Update myPresence if this is a normal presence element.
			// In other words, ignore presence subscription stuff, MUC room stuff, etc.
			
			XMPPPresence *presence = (XMPPPresence *)element;
			
			// We use the built-in [presence type] which guarantees lowercase strings,
			// and will return @"available" if there was no set type (as available is implicit).
			
			NSString *type = [presence type];
			if ([type isEqualToString:@"available"] || [type isEqualToString:@"unavailable"])
			{
				if ([presence toStr] == nil && myPresence != presence)
				{
					[myPresence release];
					myPresence = [presence retain];
				}
			}
			
			[multicastDelegate xmppStream:self didSendPresence:(XMPPPresence *)element];
		}
	}
}

/**
 * Private method.
 * Presencts a common method for the various public sendElement methods.
**/
- (void)sendElement:(NSXMLElement *)element withTag:(long)tag
{
	NSAssert(dispatch_get_current_queue() == xmppQueue, @"Invoked on incorrect queue");
	
	
	if ([element isKindOfClass:[XMPPIQ class]])
	{
		[self sendIQ:(XMPPIQ *)element withTag:tag];
	}
	else if ([element isKindOfClass:[XMPPMessage class]])
	{
		[self sendMessage:(XMPPMessage *)element withTag:tag];
	}
	else if ([element isKindOfClass:[XMPPPresence class]])
	{
		[self sendPresence:(XMPPPresence *)element withTag:tag];
	}
	else
	{
		NSString *elementName = [element name];
		
		if ([elementName isEqualToString:@"iq"])
		{
			[self sendIQ:[XMPPIQ iqFromElement:element] withTag:tag];
		}
		else if ([elementName isEqualToString:@"message"])
		{
			[self sendMessage:[XMPPMessage messageFromElement:element] withTag:tag];
		}
		else if ([elementName isEqualToString:@"presence"])
		{
			[self sendPresence:[XMPPPresence presenceFromElement:element] withTag:tag];
		}
	}
}

/**
 * This methods handles sending an XML fragment.
 * If the XMPPStream is not connected, this method does nothing.
**/
- (void)sendElement:(NSXMLElement *)element
{
	dispatch_block_t block = ^{
		
		if (state == STATE_XMPP_CONNECTED)
		{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			
			[self sendElement:element withTag:TAG_XMPP_WRITE_STREAM];
			
			[pool drain];
		}
	};
	
	if (dispatch_get_current_queue() == xmppQueue)
		block();
	else
		dispatch_async(xmppQueue, block);
}

/**
 * This method handles sending an XML fragment.
 * If the XMPPStream is not connected, this method does nothing.
 * 
 * After the element has been successfully sent,
 * the xmppStream:didSendElementWithTag: delegate method is called.
**/
- (void)sendElement:(NSXMLElement *)element andGetReceipt:(XMPPElementReceipt **)receiptPtr
{
	if (receiptPtr == nil)
	{
		[self sendElement:element];
	}
	else
	{
		__block XMPPElementReceipt *receipt = nil;
		
		dispatch_block_t block = ^{
			
			if (state == STATE_XMPP_CONNECTED)
			{
				NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
				
				receipt = [[XMPPElementReceipt alloc] init]; // autoreleased below
				[receipts addObject:receipt];
				
				[self sendElement:element withTag:TAG_XMPP_WRITE_RECEIPT];
				
				[pool drain];
			}
		};
		
		if (dispatch_get_current_queue() == xmppQueue)
			block();
		else
			dispatch_sync(xmppQueue, block);
		
		*receiptPtr = [receipt autorelease];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Stream Negotiation
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method is called to start the initial negotiation process.
**/
- (void)startNegotiation
{
	NSAssert(dispatch_get_current_queue() == xmppQueue, @"Invoked on incorrect queue");
	NSAssert(![self didStartNegotiation], @"Invoked after initial negotiation has started");
	
	XMPPLogTrace();
	
	// Initialize the XML stream
	[self sendOpeningNegotiation];
	
	// Inform delegate that the TCP connection is open, and the stream handshake has begun
	[multicastDelegate xmppStreamDidStartNegotiation:self];
	
	// Initialize socket buffer
	if (socketBuffer == nil)
	{
		socketBuffer = [[NSMutableData alloc] initWithLength:SOCKET_BUFFER_SIZE];
	}
	
	// And start reading in the server's XML stream
	[asyncSocket readDataWithTimeout:TIMEOUT_XMPP_READ_START
	                          buffer:socketBuffer
	                    bufferOffset:0
	                       maxLength:[socketBuffer length]
	                             tag:TAG_XMPP_READ_START];
}

/**
 * This method handles sending the opening <stream:stream ...> element which is needed in several situations.
**/
- (void)sendOpeningNegotiation
{
	NSAssert(dispatch_get_current_queue() == xmppQueue, @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	if ( ![self didStartNegotiation])
	{
		// TCP connection was just opened - We need to include the opening XML stanza
		NSString *s1 = @"<?xml version='1.0'?>";
		
		NSData *outgoingData = [s1 dataUsingEncoding:NSUTF8StringEncoding];
		
		XMPPLogSend(@"SEND: %@", s1);
		numberOfBytesSent += [outgoingData length];
		
		[asyncSocket writeData:outgoingData
				   withTimeout:TIMEOUT_XMPP_WRITE
						   tag:TAG_XMPP_WRITE_START];
		
		[self setDidStartNegotiation:YES];
	}
	
	if (state != STATE_XMPP_CONNECTING)
	{
		XMPPLogVerbose(@"%@: Resetting parser...", THIS_FILE);
		
		// We're restarting our negotiation, so we need to reset the parser.
		[parser setDelegate:nil];
		[parser release];
		
		parser = [(XMPPParser *)[XMPPParser alloc] initWithDelegate:self];
	}
	else if (parser == nil)
	{
		XMPPLogVerbose(@"%@: Initializing parser...", THIS_FILE);
		
		// Need to create parser (it was destroyed when the socket was last disconnected)
		parser = [(XMPPParser *)[XMPPParser alloc] initWithDelegate:self];
	}
	else
	{
		XMPPLogVerbose(@"%@: Not touching parser...", THIS_FILE);
	}
	
	NSString *xmlns = @"jabber:client";
	NSString *xmlns_stream = @"http://etherx.jabber.org/streams";
	
	NSString *temp, *s2;
    if ([self isP2P])
    {
		if (myJID && remoteJID)
		{
			temp = @"<stream:stream xmlns='%@' xmlns:stream='%@' version='1.0' from='%@' to='%@'>";
			s2 = [NSString stringWithFormat:temp, xmlns, xmlns_stream, [myJID bare], [remoteJID bare]];
		}
		else if (myJID)
		{
			temp = @"<stream:stream xmlns='%@' xmlns:stream='%@' version='1.0' from='%@'>";
			s2 = [NSString stringWithFormat:temp, xmlns, xmlns_stream, [myJID bare]];
		}
		else if (remoteJID)
		{
			temp = @"<stream:stream xmlns='%@' xmlns:stream='%@' version='1.0' to='%@'>";
			s2 = [NSString stringWithFormat:temp, xmlns, xmlns_stream, [remoteJID bare]];
		}
		else
		{
			temp = @"<stream:stream xmlns='%@' xmlns:stream='%@' version='1.0'>";
			s2 = [NSString stringWithFormat:temp, xmlns, xmlns_stream];
		}
    }
    else
    {
		if (myJID)
		{
			temp = @"<stream:stream xmlns='%@' xmlns:stream='%@' version='1.0' to='%@'>";
            s2 = [NSString stringWithFormat:temp, xmlns, xmlns_stream, [myJID domain]];
		}
        else if ([hostName length] > 0)
        {
            temp = @"<stream:stream xmlns='%@' xmlns:stream='%@' version='1.0' to='%@'>";
            s2 = [NSString stringWithFormat:temp, xmlns, xmlns_stream, hostName];
        }
        else
        {
            temp = @"<stream:stream xmlns='%@' xmlns:stream='%@' version='1.0'>";
            s2 = [NSString stringWithFormat:temp, xmlns, xmlns_stream];
        }
    }
	
	NSData *outgoingData = [s2 dataUsingEncoding:NSUTF8StringEncoding];
	
	XMPPLogSend(@"SEND: %@", s2);
	numberOfBytesSent += [outgoingData length];
	
	[asyncSocket writeData:outgoingData
			   withTimeout:TIMEOUT_XMPP_WRITE
					   tag:TAG_XMPP_WRITE_START];
	
	// Update status
	state = STATE_XMPP_OPENING;
}

/**
 * This method handles starting TLS negotiation on the socket, using the proper settings.
**/
- (void)startTLS
{
	NSAssert(dispatch_get_current_queue() == xmppQueue, @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	// Update state (part 2 - prompting delegates)
	state = STATE_XMPP_STARTTLS_2;
	
	// Create a mutable dictionary for security settings
	NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithCapacity:5];
	
	// Get a delegate enumerator
	GCDMulticastDelegateEnumerator *delegateEnumerator = [multicastDelegate delegateEnumerator];
	
	dispatch_queue_t concurrentQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
	dispatch_async(concurrentQueue, ^{
		
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		// Prompt the delegate(s) to populate the security settings
		
		SEL selector = @selector(xmppStream:willSecureWithSettings:);
		
		id delegate;
		dispatch_queue_t delegateQueue;
		
		while ([delegateEnumerator getNextDelegate:&delegate delegateQueue:&delegateQueue forSelector:selector])
		{
			dispatch_sync(delegateQueue, ^{
				NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
				
				[delegate xmppStream:self willSecureWithSettings:settings];
				
				[innerPool drain];
			});
		}
		
		dispatch_async(xmppQueue, ^{
			NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
			
			[self continueStartTLS:settings];
			
			[innerPool drain];
		});
		
		[pool drain];
	});
}

- (void)continueStartTLS:(NSMutableDictionary *)settings
{
	NSAssert(dispatch_get_current_queue() == xmppQueue, @"Invoked on incorrect queue");
	
	XMPPLogTrace2(@"%@: %@ %@", THIS_FILE, THIS_METHOD, settings);
	
	if (state == STATE_XMPP_STARTTLS_2)
	{
		// If the delegates didn't respond
		if ([settings count] == 0)
		{
			// Use the default settings, and set the peer name
			if ([hostName length] > 0)
			{
				[settings setObject:hostName forKey:(NSString *)kCFStreamSSLPeerName];
			}
		}
		
		[asyncSocket startTLS:settings];
		[self setIsSecure:YES];
		
		// Note: We don't need to wait for asyncSocket to complete TLS negotiation.
		// We can just continue reading/writing to the socket, and it will handle queueing everything for us!
		
		if ([self didStartNegotiation])
		{
			// Now we start our negotiation over again...
			[self sendOpeningNegotiation];
		}
		else
		{
			// First time starting negotiation
			[self startNegotiation];
		}
		
		// We paused reading from the socket.
		// We're ready to continue now.
		[asyncSocket readDataWithTimeout:TIMEOUT_XMPP_READ_STREAM
		                          buffer:socketBuffer
		                    bufferOffset:0
		                       maxLength:[socketBuffer length]
		                             tag:TAG_XMPP_READ_STREAM];
	}
}

/**
 * This method is called anytime we receive the server's stream features.
 * This method looks at the stream features, and handles any requirements so communication can continue.
**/
- (void)handleStreamFeatures
{
	NSAssert(dispatch_get_current_queue() == xmppQueue, @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	// Extract the stream features
	NSXMLElement *features = [rootElement elementForName:@"stream:features"];
	
	// Check to see if TLS is required
	// Don't forget about that NSXMLElement bug you reported to apple (xmlns is required or element won't be found)
	NSXMLElement *f_starttls = [features elementForName:@"starttls" xmlns:@"urn:ietf:params:xml:ns:xmpp-tls"];
	
	if (f_starttls)
	{
		if ([f_starttls elementForName:@"required"])
		{
			// TLS is required for this connection
			
			// Update state
			state = STATE_XMPP_STARTTLS_1;
			
			// Send the startTLS XML request
			[self sendStartTLSRequest];
			
			// We do not mark the stream as secure yet.
			// We're waiting to receive the <proceed/> response from the
			// server before we actually start the TLS handshake.
			
			// We're already listening for the response...
			return;
		}
	}
	
	// Check to see if resource binding is required
	// Don't forget about that NSXMLElement bug you reported to apple (xmlns is required or element won't be found)
	NSXMLElement *f_bind = [features elementForName:@"bind" xmlns:@"urn:ietf:params:xml:ns:xmpp-bind"];
	
	if (f_bind)
	{
		// Binding is required for this connection
		state = STATE_XMPP_BINDING;
		
		NSString *requestedResource = [myJID resource];
		
		if ([requestedResource length] > 0)
		{
			// Ask the server to bind the user specified resource
			
			NSXMLElement *resource = [NSXMLElement elementWithName:@"resource"];
			[resource setStringValue:requestedResource];
			
			NSXMLElement *bind = [NSXMLElement elementWithName:@"bind" xmlns:@"urn:ietf:params:xml:ns:xmpp-bind"];
			[bind addChild:resource];
			
			NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
			[iq addAttributeWithName:@"type" stringValue:@"set"];
			[iq addChild:bind];
			
			NSString *outgoingStr = [iq compactXMLString];
			NSData *outgoingData = [outgoingStr dataUsingEncoding:NSUTF8StringEncoding];
			
			XMPPLogSend(@"SEND: %@", outgoingStr);
			numberOfBytesSent += [outgoingData length];
			
			[asyncSocket writeData:outgoingData
					   withTimeout:TIMEOUT_XMPP_WRITE
							   tag:TAG_XMPP_WRITE_STREAM];
		}
		else
		{
			// The user didn't specify a resource, so we ask the server to bind one for us
			
			NSXMLElement *bind = [NSXMLElement elementWithName:@"bind" xmlns:@"urn:ietf:params:xml:ns:xmpp-bind"];
			
			NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
			[iq addAttributeWithName:@"type" stringValue:@"set"];
			[iq addChild:bind];
			
			NSString *outgoingStr = [iq compactXMLString];
			NSData *outgoingData = [outgoingStr dataUsingEncoding:NSUTF8StringEncoding];
			
			XMPPLogSend(@"SEND: %@", outgoingStr);
			numberOfBytesSent += [outgoingData length];
			
			[asyncSocket writeData:outgoingData
					   withTimeout:TIMEOUT_XMPP_WRITE
							   tag:TAG_XMPP_WRITE_STREAM];
		}
		
		// We're already listening for the response...
		return;
	}
	
	// It looks like all has gone well, and the connection should be ready to use now
	state = STATE_XMPP_CONNECTED;
	
	if (![self isAuthenticated])
	{
		[self setupKeepAliveTimer];
		
		// Notify delegates
		[multicastDelegate xmppStreamDidConnect:self];
	}
}

- (void)handleStartTLSResponse:(NSXMLElement *)response
{
	NSAssert(dispatch_get_current_queue() == xmppQueue, @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	// We're expecting a proceed response
	// If we get anything else we can safely assume it's the equivalent of a failure response
	if ( ![[response name] isEqualToString:@"proceed"])
	{
		// We can close our TCP connection now
		[self disconnect];
		
		// The socketDidDisconnect:withError: method will handle everything else
		return;
	}
	
	// Start TLS negotiation
	[self startTLS];
}

/**
 * After the registerUser:withPassword: method is invoked, a registration message is sent to the server.
 * We're waiting for the result from this registration request.
**/
- (void)handleRegistration:(NSXMLElement *)response
{
	NSAssert(dispatch_get_current_queue() == xmppQueue, @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	if ([[response attributeStringValueForName:@"type"] isEqualToString:@"error"])
	{
		// Revert back to connected state (from authenticating state)
		state = STATE_XMPP_CONNECTED;
		
		[multicastDelegate xmppStream:self didNotRegister:response];
	}
	else
	{
		// Revert back to connected state (from authenticating state)
		state = STATE_XMPP_CONNECTED;
		
		[multicastDelegate xmppStreamDidRegister:self];
	}
}

/**
 * After the authenticateWithPassword:error: or authenticateWithFacebookAccessToken:error: methods are invoked, an 
 * authentication message is sent to the server.
 * If the server supports digest-md5 sasl authentication, it is used.  Otherwise plain sasl authentication is used,
 * assuming the server supports it.
 * 
 * Now if digest-md5 or X-FACEBOOK-PLATFORM was used, we sent a challenge request, and we're waiting for a 
 * challenge response.  If plain sasl was used, we sent our authentication information, and we're waiting for a 
 * success response.
**/
- (void)handleAuth1:(NSXMLElement *)response
{
	NSAssert(dispatch_get_current_queue() == xmppQueue, @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
  if ([self supportsDigestMD5Authentication] || isAccessToken)
	{
		// We're expecting a challenge response
		// If we get anything else we can safely assume it's the equivalent of a failure response
		if ( ![[response name] isEqualToString:@"challenge"])
		{
			// Revert back to connected state (from authenticating state)
			state = STATE_XMPP_CONNECTED;
			
			[multicastDelegate xmppStream:self didNotAuthenticate:response];
		}
		else
		{
			// Create authentication object from the given challenge
			// We'll release this object at the end of this else block
      id<XMPPSASLAuthentication> auth = nil;
      
      if (isAccessToken)
      {
        auth = [[XMPPXFacebookPlatformAuthentication alloc] initWithChallenge:response 
                                                                        appId:self.appId 
                                                                    accessToken:tempPassword];

        // Update state
          state = STATE_XMPP_AUTH_3;
      }
      else
      {
        auth = [[XMPPDigestAuthentication alloc] initWithChallenge:response];
        
        NSString *virtualHostName = [myJID domain];
        NSString *serverHostName = hostName;
        
        // Sometimes the realm isn't specified
        // In this case I believe the realm is implied as the virtual host name
        if (![(XMPPDigestAuthentication *)auth realm])
        {
          if([virtualHostName length] > 0)
            [(XMPPDigestAuthentication *)auth setRealm:virtualHostName];
          else
            [(XMPPDigestAuthentication *)auth setRealm:serverHostName];
        }
        
        // Set digest-uri
        if([virtualHostName length] > 0)
          [(XMPPDigestAuthentication *)auth setDigestURI:[NSString stringWithFormat:@"xmpp/%@", virtualHostName]];
        else
          [(XMPPDigestAuthentication *)auth setDigestURI:[NSString stringWithFormat:@"xmpp/%@", serverHostName]];
        
        // Set username and password
        [(XMPPDigestAuthentication *)auth setUsername:[myJID user] password:tempPassword];

        // Update state
        state = STATE_XMPP_AUTH_2;
      }
			
			// Create and send challenge response element
			NSXMLElement *cr = [NSXMLElement elementWithName:@"response" xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
			[cr setStringValue:[auth base64EncodedFullResponse]];
			
			NSString *outgoingStr = [cr compactXMLString];
			NSData *outgoingData = [outgoingStr dataUsingEncoding:NSUTF8StringEncoding];
			
			XMPPLogSend(@"SEND: %@", outgoingStr);
			numberOfBytesSent += [outgoingData length];
			
			[asyncSocket writeData:outgoingData
					   withTimeout:TIMEOUT_XMPP_WRITE
							   tag:TAG_XMPP_WRITE_STREAM];
						
      // Release unneeded resources
			[auth release];
      isAccessToken = NO;
			[tempPassword release]; tempPassword = nil;
		}
	}
	else if ([self supportsPlainAuthentication])
	{
		// We're expecting a success response
		// If we get anything else we can safely assume it's the equivalent of a failure response
		if ( ![[response name] isEqualToString:@"success"])
		{
			// Revert back to connected state (from authenticating state)
			state = STATE_XMPP_CONNECTED;
			
			[multicastDelegate xmppStream:self didNotAuthenticate:response];
		}
		else
		{
			// We are successfully authenticated (via sasl:plain)
			[self setIsAuthenticated:YES];
			
			// Now we start our negotiation over again...
			[self sendOpeningNegotiation];
		}
	}
	else
	{
		// We used the old fashioned jabber:iq:auth mechanism
		
		if ([[response attributeStringValueForName:@"type"] isEqualToString:@"error"])
		{
			// Revert back to connected state (from authenticating state)
			state = STATE_XMPP_CONNECTED;
			
			[multicastDelegate xmppStream:self didNotAuthenticate:response];
		}
		else
		{
			// We are successfully authenticated (via non-sasl:digest)
			// And we've binded our resource as well
			[self setIsAuthenticated:YES];
			
			// Revert back to connected state (from authenticating state)
			state = STATE_XMPP_CONNECTED;
			
			[multicastDelegate xmppStreamDidAuthenticate:self];
		}
	}
}

/**
 * This method handles the result of our challenge response we sent in handleAuth1 using digest-md5 sasl.
**/
- (void)handleAuth2:(NSXMLElement *)response
{
	NSAssert(dispatch_get_current_queue() == xmppQueue, @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	if ([[response name] isEqualToString:@"challenge"])
	{
		XMPPDigestAuthentication *auth = [[[XMPPDigestAuthentication alloc] initWithChallenge:response] autorelease];
		
		if(![auth rspauth])
		{
			// We're getting another challenge???
			// I'm not sure what this could possibly be, so for now I'll assume it's a failure
			
			// Revert back to connected state (from authenticating state)
			state = STATE_XMPP_CONNECTED;
			
			[multicastDelegate xmppStream:self didNotAuthenticate:response];
		}
		else
		{
			// We received another challenge, but it's really just an rspauth
			// This is supposed to be included in the success element (according to the updated RFC)
			// but many implementations incorrectly send it inside a second challenge request.
			
			// Create and send empty challenge response element
			NSXMLElement *cr = [NSXMLElement elementWithName:@"response" xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
			
			NSString *outgoingStr = [cr compactXMLString];
			NSData *outgoingData = [outgoingStr dataUsingEncoding:NSUTF8StringEncoding];
			
			XMPPLogSend(@"SEND: %@", outgoingStr);
			numberOfBytesSent += [outgoingData length];
			
			[asyncSocket writeData:outgoingData
					   withTimeout:TIMEOUT_XMPP_WRITE
							   tag:TAG_XMPP_WRITE_STREAM];
			
			// The state remains in STATE_XMPP_AUTH_2
		}
	}
	else if ([[response name] isEqualToString:@"success"])
	{
		// We are successfully authenticated (via sasl:digest-md5)
		[self setIsAuthenticated:YES];
		
		// Now we start our negotiation over again...
		[self sendOpeningNegotiation];
	}
	else
	{
		// We received some kind of <failure/> element
		
		// Revert back to connected state (from authenticating state)
		state = STATE_XMPP_CONNECTED;
		
		[multicastDelegate xmppStream:self didNotAuthenticate:response];
	}
}

/**
 * This method handles the result of our SASL Anonymous Authentication challenge
**/
- (void)handleAuth3:(NSXMLElement *)response
{
	NSAssert(dispatch_get_current_queue() == xmppQueue, @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	// We're expecting a success response
	// If we get anything else we can safely assume it's the equivalent of a failure response
	if ( ![[response name] isEqualToString:@"success"])
	{
		// Revert back to connected state (from authenticating state)
		state = STATE_XMPP_CONNECTED;
		
		[multicastDelegate xmppStream:self didNotAuthenticate:response];
	}
	else
	{
		// We are successfully authenticated (via sasl:x-facebook-platform or sasl:plain)
		[self setIsAuthenticated:YES];
		
		// Now we start our negotiation over again...
		[self sendOpeningNegotiation];
	}
}

- (void)handleBinding:(NSXMLElement *)response
{
	NSAssert(dispatch_get_current_queue() == xmppQueue, @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	NSXMLElement *r_bind = [response elementForName:@"bind" xmlns:@"urn:ietf:params:xml:ns:xmpp-bind"];
	NSXMLElement *r_jid = [r_bind elementForName:@"jid"];
	
	if (r_jid)
	{
		// We're properly binded to a resource now
		// Extract and save our resource (it may not be what we originally requested)
		NSString *fullJIDStr = [r_jid stringValue];
		
		[self setMyJID:[XMPPJID jidWithString:fullJIDStr]];
		
		// And we may now have to do one last thing before we're ready - start an IM session
		NSXMLElement *features = [rootElement elementForName:@"stream:features"];
		
		// Check to see if a session is required
		// Don't forget about that NSXMLElement bug you reported to apple (xmlns is required or element won't be found)
		NSXMLElement *f_session = [features elementForName:@"session" xmlns:@"urn:ietf:params:xml:ns:xmpp-session"];
		
		if (f_session)
		{
			NSXMLElement *session = [NSXMLElement elementWithName:@"session"];
			[session setXmlns:@"urn:ietf:params:xml:ns:xmpp-session"];
			
			NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
			[iq addAttributeWithName:@"type" stringValue:@"set"];
			[iq addChild:session];
			
			NSString *outgoingStr = [iq compactXMLString];
			NSData *outgoingData = [outgoingStr dataUsingEncoding:NSUTF8StringEncoding];
			
			XMPPLogSend(@"SEND: %@", outgoingStr);
			numberOfBytesSent += [outgoingData length];
			
			[asyncSocket writeData:outgoingData
					   withTimeout:TIMEOUT_XMPP_WRITE
							   tag:TAG_XMPP_WRITE_STREAM];
			
			// Update state
			state = STATE_XMPP_START_SESSION;
		}
		else
		{
			// Revert back to connected state (from binding state)
			state = STATE_XMPP_CONNECTED;
			
			[multicastDelegate xmppStreamDidAuthenticate:self];
		}
	}
	else
	{
		// It appears the server didn't allow our resource choice
		// We'll simply let the server choose then
		
		NSXMLElement *bind = [NSXMLElement elementWithName:@"bind" xmlns:@"urn:ietf:params:xml:ns:xmpp-bind"];
		
		NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
		[iq addAttributeWithName:@"type" stringValue:@"set"];
		[iq addChild:bind];
		
		NSString *outgoingStr = [iq compactXMLString];
		NSData *outgoingData = [outgoingStr dataUsingEncoding:NSUTF8StringEncoding];
		
		XMPPLogSend(@"SEND: %@", outgoingStr);
		numberOfBytesSent += [outgoingData length];
		
		[asyncSocket writeData:outgoingData
				   withTimeout:TIMEOUT_XMPP_WRITE
						   tag:TAG_XMPP_WRITE_STREAM];
		
		// The state remains in STATE_XMPP_BINDING
	}
}

- (void)handleStartSessionResponse:(NSXMLElement *)response
{
	NSAssert(dispatch_get_current_queue() == xmppQueue, @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	if ([[response attributeStringValueForName:@"type"] isEqualToString:@"result"])
	{
		// Revert back to connected state (from start session state)
		state = STATE_XMPP_CONNECTED;
		
		[multicastDelegate xmppStreamDidAuthenticate:self];
	}
	else
	{
		// Revert back to connected state (from start session state)
		state = STATE_XMPP_CONNECTED;
		
		[multicastDelegate xmppStream:self didNotAuthenticate:response];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPSRVResolver Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)tryNextSrvResult
{
	NSAssert(dispatch_get_current_queue() == xmppQueue, @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	NSError *connectError = nil;
	BOOL success = NO;
	
	while (srvResultsIndex < [srvResults count])
	{
		XMPPSRVRecord *srvRecord = [srvResults objectAtIndex:srvResultsIndex];
		NSString *srvHost = srvRecord.target;
		UInt16 srvPort    = srvRecord.port;
		
		success = [self connectToHost:srvHost onPort:srvPort error:&connectError];
		
		if (success)
		{
			break;
		}
		else
		{
			srvResultsIndex++;
		}
	}
	
	if (!success)
	{
		// SRV resolution of the JID domain failed.
		// As per the RFC:
		// 
		// "If the SRV lookup fails, the fallback is a normal IPv4/IPv6 address record resolution
		// to determine the IP address, using the "xmpp-client" port 5222, registered with the IANA."
		// 
		// In other words, just try connecting to the domain specified in the JID.
		
		success = [self connectToHost:[myJID domain] onPort:5222 error:&connectError];
	}
	
	if (!success)
	{
		state = STATE_XMPP_DISCONNECTED;
		
		[multicastDelegate xmppStreamDidDisconnect:self withError:connectError];
	}
}

- (void)srvResolver:(XMPPSRVResolver *)sender didResolveRecords:(NSArray *)records
{
	NSAssert(dispatch_get_current_queue() == xmppQueue, @"Invoked on incorrect queue");
	
	if (sender != srvResolver) return;
	
	XMPPLogTrace();
	
	srvResults = [records copy];
	srvResultsIndex = 0;
	
	state = STATE_XMPP_CONNECTING;
	
	[self tryNextSrvResult];
}

- (void)srvResolver:(XMPPSRVResolver *)sender didNotResolveDueToError:(NSError *)error
{
	NSAssert(dispatch_get_current_queue() == xmppQueue, @"Invoked on incorrect queue");
	
	if (sender != srvResolver) return;
	
	XMPPLogTrace();
	
	state = STATE_XMPP_CONNECTING;
	
	[self tryNextSrvResult];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark AsyncSocket Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Called when a socket connects and is ready for reading and writing. "host" will be an IP address, not a DNS name.
**/
- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port
{
	// This method is invoked on the xmppQueue.
	// 
	// The TCP connection is now established.
	
	XMPPLogTrace();
	
	#if TARGET_OS_IPHONE
	{
		if (self.enableBackgroundingOnSocket)
		{
			__block BOOL result;
			
			[asyncSocket performBlock:^{
				result = [asyncSocket enableBackgroundingOnSocket];
			}];
			
			if (result)
				XMPPLogVerbose(@"%@: Enabled backgrounding on socket", THIS_FILE);
			else
				XMPPLogError(@"%@: Error enabling backgrounding on socket!", THIS_FILE);
		}
	}
	#endif
	
	[multicastDelegate xmppStream:self socketDidConnect:sock];
	
	[srvResolver release];
	srvResolver = nil;
	
	[srvResults release];
	srvResults = nil;
	
	// Are we using old-style SSL? (Not the upgrade to TLS technique specified in the XMPP RFC)
	if ([self isSecure])
	{
		// The connection must be secured immediately (just like with HTTPS)
		[self startTLS];
	}
	else
	{
		[self startNegotiation];
	}
}

- (void)socketDidSecure:(GCDAsyncSocket *)sock
{
	// This method is invoked on the xmppQueue.
	
	XMPPLogTrace();
	
	[multicastDelegate xmppStreamDidSecure:self];
}

/**
 * Called when a socket has completed reading the requested data. Not called if there is an error.
**/
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
	// This method is invoked on the xmppQueue.
	
	XMPPLogTrace();
	
	lastSendReceiveTime = [NSDate timeIntervalSinceReferenceDate];
	
	if (XMPP_LOG_RECV_PRE)
	{
		NSString *dataAsStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
		
		XMPPLogRecvPre(@"RECV: %@", dataAsStr);
		
		[dataAsStr release];
	}
	
	numberOfBytesReceived += [data length];
	
	dispatch_async(parserQueue, ^{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		[parser parseData:data];
		
		dispatch_async(xmppQueue, ^{
			NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
			
			// Continue reading for XML elements.
			
			if (state == STATE_XMPP_OPENING)
			{
				[asyncSocket readDataWithTimeout:TIMEOUT_XMPP_READ_START
										  buffer:socketBuffer
									bufferOffset:0
									   maxLength:[socketBuffer length]
											 tag:TAG_XMPP_READ_START];
			}
			else if (state != STATE_XMPP_STARTTLS_2)
			{
				[asyncSocket readDataWithTimeout:TIMEOUT_XMPP_READ_STREAM
										  buffer:socketBuffer
									bufferOffset:0
									   maxLength:[socketBuffer length]
											 tag:TAG_XMPP_READ_STREAM];
			}
			
			[innerPool drain];
		});
		
		[pool drain];
	});
}

/**
 * Called after data with the given tag has been successfully sent.
**/
- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
	// This method is invoked on the xmppQueue.
	
	XMPPLogTrace();
	
	lastSendReceiveTime = [NSDate timeIntervalSinceReferenceDate];
	
	if (tag == TAG_XMPP_WRITE_RECEIPT)
	{
		if ([receipts count] == 0)
		{
			XMPPLogWarn(@"%@: Found TAG_XMPP_WRITE_RECEIPT with no pending receipts!", THIS_FILE);
			return;
		}
		
		XMPPElementReceipt *receipt = [receipts objectAtIndex:0];
		[receipt signalSuccess];
		[receipts removeObjectAtIndex:0];
	}
}

/**
 * Called when a socket disconnects with or without error.
**/
- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
	// This method is invoked on the xmppQueue.
	
	XMPPLogTrace();
	
	if (srvResults && (++srvResultsIndex < [srvResults count]))
	{
		[self tryNextSrvResult];
	}
	else
	{
		// Update state
		state = STATE_XMPP_DISCONNECTED;
		
		// Release socket buffer
		[socketBuffer release];
		socketBuffer = nil;
		
		// Release the parser (to free underlying resources)
		[parser setDelegate:nil];
		[parser release];
		parser = nil;
		
		// Clear any saved authentication information
    isAccessToken = NO;
		[tempPassword release]; tempPassword = nil;
		
		// Clear stored elements
		[myPresence release]; myPresence = nil;
		[rootElement release]; rootElement = nil;
		
		// Stop the keep alive timer
		if (keepAliveTimer)
		{
			dispatch_source_cancel(keepAliveTimer);
			keepAliveTimer = NULL;
		}
		
		// Clear srv results
		[srvResolver release]; srvResolver = nil;
		[srvResults release];  srvResults = nil;
		
		// Clear any pending receipts
		for (XMPPElementReceipt *receipt in receipts)
		{
			[receipt signalFailure];
		}
		[receipts removeAllObjects];
		
		// Clear flags
		flags = 0;
		
		// Notify delegate
		
		if (parserError)
		{
			[multicastDelegate xmppStreamDidDisconnect:self withError:parserError];
			
			[parserError release];
			parserError = nil;
		}
		else
		{
			[multicastDelegate xmppStreamDidDisconnect:self withError:err];
		}
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPParser Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Called when the xmpp parser has read in the entire root element.
**/
- (void)xmppParser:(XMPPParser *)sender didReadRoot:(NSXMLElement *)root
{
	NSAssert(dispatch_get_current_queue() == parserQueue, @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	dispatch_async(xmppQueue, ^{
		
		if (sender != parser) return_from_block;
		
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
		XMPPLogRecvPost(@"RECV: %@", [root compactXMLString]);
		
		// At this point we've sent our XML stream header, and we've received the response XML stream header.
		// We save the root element of our stream for future reference.
		// Digest Access authentication requires us to know the ID attribute from the <stream:stream/> element.
		
		[rootElement release];
		rootElement = [root retain];
		
		if ([self isP2P])
		{
			// XEP-0174 specifies that <stream:features/> SHOULD be sent by the receiver.
			// In other words, if we're the recipient we will now send our features.
			// But if we're the initiator, we can't depend on receiving their features.
			
			// Either way, we're connected at this point.
			state = STATE_XMPP_CONNECTED;
			
			if ([self isP2PRecipient])
			{
				// Extract the remoteJID:
				// 
				// <stream:stream ... from='<remoteJID>' to='<myJID>'>
				
				NSString *from = [[rootElement attributeForName:@"from"] stringValue];
				remoteJID = [[XMPPJID jidWithString:from] retain];
				
				// Send our stream features.
				// To do so we need to ask the delegate to fill it out for us.
				
				NSXMLElement *streamFeatures = [NSXMLElement elementWithName:@"stream:features"];
				
				[multicastDelegate xmppStream:self willSendP2PFeatures:streamFeatures];
				
				NSString *outgoingStr = [streamFeatures compactXMLString];
				NSData *outgoingData = [outgoingStr dataUsingEncoding:NSUTF8StringEncoding];
				
				XMPPLogSend(@"SEND: %@", outgoingStr);
				numberOfBytesSent += [outgoingData length];
				
				[asyncSocket writeData:outgoingData
						   withTimeout:TIMEOUT_XMPP_WRITE
								   tag:TAG_XMPP_WRITE_STREAM];
				
			}
			
			// Make sure the delegate didn't disconnect us in the xmppStream:willSendP2PFeatures: method.
			
			if ([self isConnected])
			{
				[multicastDelegate xmppStreamDidConnect:self];
			}
		}
		else
		{
			// Check for RFC compliance
			if ([self serverXmppStreamVersionNumber] >= 1.0)
			{
				// Update state - we're now onto stream negotiations
				state = STATE_XMPP_NEGOTIATING;
				
				// Note: We're waiting for the <stream:features> now
			}
			else
			{
				// The server isn't RFC comliant, and won't be sending any stream features.
				
				// We would still like to know what authentication features it supports though,
				// so we'll use the jabber:iq:auth namespace, which was used prior to the RFC spec.
				
				// Update state - we're onto psuedo negotiation
				state = STATE_XMPP_NEGOTIATING;
				
				NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"jabber:iq:auth"];
				
				NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
				[iq addAttributeWithName:@"type" stringValue:@"get"];
				[iq addChild:query];
				
				NSString *outgoingStr = [iq compactXMLString];
				NSData *outgoingData = [outgoingStr dataUsingEncoding:NSUTF8StringEncoding];
				
				XMPPLogSend(@"SEND: %@", outgoingStr);
				numberOfBytesSent += [outgoingData length];
				
				[asyncSocket writeData:outgoingData
						   withTimeout:TIMEOUT_XMPP_WRITE
								   tag:TAG_XMPP_WRITE_STREAM];
				
				// Now wait for the response IQ
			}
		}
		
		[pool drain];
	});
}

- (void)xmppParser:(XMPPParser *)sender didReadElement:(NSXMLElement *)element
{
	NSAssert(dispatch_get_current_queue() == parserQueue, @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	dispatch_async(xmppQueue, ^{
		
		if (sender != parser) return_from_block;
		
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		XMPPLogRecvPost(@"RECV: %@", [element compactXMLString]);
		
		NSString *elementName = [element name];
		
		if ([elementName isEqualToString:@"stream:error"] || [elementName isEqualToString:@"error"])
		{
			[multicastDelegate xmppStream:self didReceiveError:element];
			
			[pool drain];
			return;
		}
		
		if (state == STATE_XMPP_NEGOTIATING)
		{
			// We've just read in the stream features
			// We consider this part of the root element, so we'll add it (replacing any previously sent features)
			[rootElement setChildren:[NSArray arrayWithObject:element]];
			
			// Call a method to handle any requirements set forth in the features
			[self handleStreamFeatures];
		}
		else if (state == STATE_XMPP_STARTTLS_1)
		{
			// The response from our starttls message
			[self handleStartTLSResponse:element];
		}
		else if (state == STATE_XMPP_REGISTERING)
		{
			// The iq response from our registration request
			[self handleRegistration:element];
		}
		else if (state == STATE_XMPP_AUTH_1)
		{
			// The challenge response from our auth message
			[self handleAuth1:element];
		}
		else if (state == STATE_XMPP_AUTH_2)
		{
			// The response from our challenge response
			[self handleAuth2:element];
		}
		else if (state == STATE_XMPP_AUTH_3)
		{
			// The response from our x-facebook-platform or authenticateAnonymously challenge
			[self handleAuth3:element];
		}
		else if (state == STATE_XMPP_BINDING)
		{
			// The response from our binding request
			[self handleBinding:element];
		}
		else if (state == STATE_XMPP_START_SESSION)
		{
			// The response from our start session request
			[self handleStartSessionResponse:element];
		}
		else
		{
			if ([elementName isEqualToString:@"iq"])
			{
				XMPPIQ *iq = [XMPPIQ iqFromElement:element];
				
				// Notify all interested delegates about the received IQ.
				// Keep track of whether the delegates respond to the IQ.
				
				GCDMulticastDelegateEnumerator *delegateEnumerator = [multicastDelegate delegateEnumerator];
				
				id del;
				dispatch_queue_t dq;
				
				SEL selector = @selector(xmppStream:didReceiveIQ:);
				
				dispatch_semaphore_t delSemaphore = dispatch_semaphore_create(0);
				dispatch_group_t delGroup = dispatch_group_create();
				
				while ([delegateEnumerator getNextDelegate:&del delegateQueue:&dq forSelector:selector])
				{
					dispatch_group_async(delGroup, dq, ^{
						NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
						
						if ([del xmppStream:self didReceiveIQ:iq])
						{
							dispatch_semaphore_signal(delSemaphore);
						}
						
						[innerPool release];
					});
				}
				
				dispatch_queue_t concurrentQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
				dispatch_async(concurrentQueue, ^{
					NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
					
					dispatch_group_wait(delGroup, DISPATCH_TIME_FOREVER);
					
					// Did any of the delegates respond to the IQ?
					
					BOOL responded = (dispatch_semaphore_wait(delSemaphore, DISPATCH_TIME_NOW) == 0);
					
					// An entity that receives an IQ request of type "get" or "set" MUST reply
					// with an IQ response of type "result" or "error".
					// 
					// The response MUST preserve the 'id' attribute of the request.
					
					if (!responded && [iq requiresResponse])
					{
						// Return error message:
						// 
						// <iq to="jid" type="error" id="id">
						//   <query xmlns="ns"/>
						//   <error type="cancel" code="501">
						//     <feature-not-implemented xmlns="urn:ietf:params:xml:ns:xmpp-stanzas"/>
						//   </error>
						// </iq>
						
						NSXMLElement *reason = [NSXMLElement elementWithName:@"feature-not-implemented"
																	   xmlns:@"urn:ietf:params:xml:ns:xmpp-stanzas"];
						
						NSXMLElement *error = [NSXMLElement elementWithName:@"error"];
						[error addAttributeWithName:@"type" stringValue:@"cancel"];
						[error addAttributeWithName:@"code" stringValue:@"501"];
						[error addChild:reason];
						
						XMPPIQ *iqResponse = [XMPPIQ iqWithType:@"error"
						                                     to:[iq from]
						                              elementID:[iq elementID]
						                                  child:error];
						
						NSXMLElement *iqChild = [iq childElement];
						if (iqChild)
						{
							NSXMLNode *iqChildCopy = [iqChild copy];
							[iqResponse insertChild:iqChildCopy atIndex:0];
							[iqChildCopy release];
						}
						
						// Purposefully go through the sendElement: method
						// so that it gets dispatched onto the xmppQueue,
						// and so that modules may get notified of the outgoing error message.
						
						[self sendElement:iqResponse];
					}
					
					dispatch_release(delSemaphore);
					dispatch_release(delGroup);
					
					[outerPool drain];
				});
			
			}
			else if ([elementName isEqualToString:@"message"])
			{
				[multicastDelegate xmppStream:self didReceiveMessage:[XMPPMessage messageFromElement:element]];
			}
			else if ([elementName isEqualToString:@"presence"])
			{
				[multicastDelegate xmppStream:self didReceivePresence:[XMPPPresence presenceFromElement:element]];
			}
			else if ([self isP2P] &&
					([elementName isEqualToString:@"stream:features"] || [elementName isEqualToString:@"features"]))
			{
				[multicastDelegate xmppStream:self didReceiveP2PFeatures:element];
			}
			else
			{
				[multicastDelegate xmppStream:self didReceiveError:element];
			}
		}
		
		[pool drain];
	});
}

- (void)xmppParserDidEnd:(XMPPParser *)sender
{
	NSAssert(dispatch_get_current_queue() == parserQueue, @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	dispatch_async(xmppQueue, ^{
		
		if (sender != parser) return_from_block;
		
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		[asyncSocket disconnect];
		
		[pool drain];
	});
}

- (void)xmppParser:(XMPPParser *)sender didFail:(NSError *)error
{
	NSAssert(dispatch_get_current_queue() == parserQueue, @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	dispatch_async(xmppQueue, ^{
		
		if (sender != parser) return_from_block;
		
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		[parserError release];
		parserError = [error retain];
		
		[asyncSocket disconnect];
		
		[pool drain];
	});
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Keep Alive
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)setupKeepAliveTimer
{
	NSAssert(dispatch_get_current_queue() == xmppQueue, @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	if (keepAliveTimer)
	{
		dispatch_source_cancel(keepAliveTimer);
		keepAliveTimer = NULL;
	}
	
	if (state == STATE_XMPP_CONNECTED)
	{
		if (keepAliveInterval > 0)
		{
			keepAliveTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, xmppQueue);
			
			dispatch_source_set_event_handler(keepAliveTimer, ^{
				NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
				[self keepAlive];
				[pool drain];
			});
			
			dispatch_source_t theKeepAliveTimer = keepAliveTimer;
			
			dispatch_source_set_cancel_handler(keepAliveTimer, ^{
				XMPPLogVerbose(@"dispatch_release(keepAliveTimer)");
				dispatch_release(theKeepAliveTimer);
			});
			
			// Everytime we send or receive data, we update our lastSendReceiveTime.
			// We set our timer to fire several times per keepAliveInterval.
			// This allows us to maintain a single timer,
			// and an acceptable timer resolution (assuming larger keepAliveIntervals).
			
			uint64_t interval = ((keepAliveInterval / 4.0) * NSEC_PER_SEC);
			
			dispatch_time_t tt = dispatch_time(DISPATCH_TIME_NOW, interval);
			
			dispatch_source_set_timer(keepAliveTimer, tt, interval, 1.0);
			dispatch_resume(keepAliveTimer);
		}
	}
}

- (void)keepAlive
{
	NSAssert(dispatch_get_current_queue() == xmppQueue, @"Invoked on incorrect queue");
	
	if (state == STATE_XMPP_CONNECTED)
	{
		NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
		NSTimeInterval elapsed = (now - lastSendReceiveTime);
		
		if (elapsed < 0 || elapsed >= keepAliveInterval)
		{
			NSData *outgoingData = [@" " dataUsingEncoding:NSUTF8StringEncoding];
			
			numberOfBytesSent += [outgoingData length];
			
			[asyncSocket writeData:outgoingData
			           withTimeout:TIMEOUT_XMPP_WRITE
			                   tag:TAG_XMPP_WRITE_STREAM];
			
			// Force update the lastSendReceiveTime here just to be safe.
			// 
			// In case the TCP socket comes to a crawl with a giant element in the queue,
			// which would prevent the socket:didWriteDataWithTag: method from being called for some time.
			
			lastSendReceiveTime = [NSDate timeIntervalSinceReferenceDate];
		}
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Module Plug-In System
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)registerModule:(XMPPModule *)module
{
	if (module == nil) return;
	
	// Asynchronous operation
	
	dispatch_block_t block = ^{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		// Register module
		
		[registeredModules add:module];
		
		// Add auto delegates (if there are any)
		
		NSString *className = NSStringFromClass([module class]);
		GCDMulticastDelegate *autoDelegates = [autoDelegateDict objectForKey:className];
		
		GCDMulticastDelegateEnumerator *autoDelegatesEnumerator = [autoDelegates delegateEnumerator];
		id delegate;
		dispatch_queue_t delegateQueue;
		
		while ([autoDelegatesEnumerator getNextDelegate:&delegate delegateQueue:&delegateQueue])
		{
			[module addDelegate:delegate delegateQueue:delegateQueue];
		}
		
		// Notify our own delegate(s)
		
		[multicastDelegate xmppStream:self didRegisterModule:module];
		
		[pool drain];
	};
	
	// Asynchronous operation
	
	if (dispatch_get_current_queue() == xmppQueue)
		block();
	else
		dispatch_async(xmppQueue, block);
}

- (void)unregisterModule:(XMPPModule *)module
{
	if (module == nil) return;
	
	// Synchronous operation
	
	dispatch_block_t block = ^{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		// Notify our own delegate(s)
		
		[multicastDelegate xmppStream:self willUnregisterModule:module];
		
		// Remove auto delegates (if there are any)
		
		NSString *className = NSStringFromClass([module class]);
		GCDMulticastDelegate *autoDelegates = [autoDelegateDict objectForKey:className];
		
		GCDMulticastDelegateEnumerator *autoDelegatesEnumerator = [autoDelegates delegateEnumerator];
		id delegate;
		dispatch_queue_t delegateQueue;
		
		while ([autoDelegatesEnumerator getNextDelegate:&delegate delegateQueue:&delegateQueue])
		{
			[module removeDelegate:delegate delegateQueue:delegateQueue];
		}
		
		// Unregister modules
		
		[registeredModules remove:module];
		
		[pool drain];
	};
	
	// Synchronous operation
	
	if (dispatch_get_current_queue() == xmppQueue)
		block();
	else
		dispatch_sync(xmppQueue, block);
}

- (void)autoAddDelegate:(id)delegate delegateQueue:(dispatch_queue_t)delegateQueue toModulesOfClass:(Class)aClass
{
	if (delegate == nil) return;
	if (aClass == nil) return;
	
	// Asynchronous operation
	
	dispatch_block_t block = ^{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		NSString *className = NSStringFromClass(aClass);
		
		// Add the delegate to all currently registered modules of the given class.
		
		DDListEnumerator *registeredModulesEnumerator = [registeredModules listEnumerator];
		XMPPModule *module;
		
		while ((module = (XMPPModule *)[registeredModulesEnumerator nextElement]))
		{
			if ([module isKindOfClass:aClass])
			{
				[module addDelegate:delegate delegateQueue:delegateQueue];
			}
		}
		
		// Add the delegate to list of auto delegates for the given class.
		// It will be added as a delegate to future registered modules of the given class.
		
		id delegates = [autoDelegateDict objectForKey:className];
		
		if (delegates == nil)
		{
			delegates = [[[GCDMulticastDelegate alloc] init] autorelease];
			
			[autoDelegateDict setObject:delegates forKey:className];
		}
		
		[delegates addDelegate:delegate delegateQueue:delegateQueue];
		
		[pool drain];
	};
	
	// Asynchronous operation
	
	if (dispatch_get_current_queue() == xmppQueue)
		block();
	else
		dispatch_async(xmppQueue, block);
}

- (void)removeAutoDelegate:(id)delegate delegateQueue:(dispatch_queue_t)delegateQueue fromModulesOfClass:(Class)aClass
{
	if (delegate == nil) return;
	// delegateQueue may be NULL
	// aClass may be NULL
	
	// Synchronous operation
	
	dispatch_block_t block = ^{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		if (aClass == NULL)
		{
			// Remove the delegate from all currently registered modules of ANY class.
			
			DDListEnumerator *registeredModulesEnumerator = [registeredModules listEnumerator];
			XMPPModule *module;
			
			while ((module = (XMPPModule *)[registeredModulesEnumerator nextElement]))
			{
				[module removeDelegate:delegate delegateQueue:delegateQueue];
			}
			
			// Remove the delegate from list of auto delegates for all classes,
			// so that it will not be auto added as a delegate to future registered modules.
			
			for (GCDMulticastDelegate *delegates in [autoDelegateDict objectEnumerator])
			{
				[delegates removeDelegate:delegate delegateQueue:delegateQueue];
			}
		}
		else
		{
			NSString *className = NSStringFromClass(aClass);
			
			// Remove the delegate from all currently registered modules of the given class.
			
			DDListEnumerator *registeredModulesEnumerator = [registeredModules listEnumerator];
			XMPPModule *module;
			
			while ((module = (XMPPModule *)[registeredModulesEnumerator nextElement]))
			{
				if ([module isKindOfClass:aClass])
				{
					[module removeDelegate:delegate delegateQueue:delegateQueue];
				}
			}
			
			// Remove the delegate from list of auto delegates for the given class,
			// so that it will not be added as a delegate to future registered modules of the given class.
			
			GCDMulticastDelegate *delegates = [autoDelegateDict objectForKey:className];
			[delegates removeDelegate:delegate delegateQueue:delegateQueue];
		}
		
		[pool drain];
	};
	
	// Synchronous operation
	
	if (dispatch_get_current_queue() == xmppQueue)
		block();
	else
		dispatch_sync(xmppQueue, block);
}

- (void)enumerateModulesWithBlock:(void (^)(XMPPModule *module, NSUInteger idx, BOOL *stop))enumBlock
{
	if (enumBlock == NULL) return;
	
	dispatch_block_t block = ^{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		DDListEnumerator *registeredModulesEnumerator = [registeredModules listEnumerator];
		
		XMPPModule *module;
		NSUInteger i = 0;
		BOOL stop = NO;
		
		while ((module = (XMPPModule *)[registeredModulesEnumerator nextElement]))
		{
			enumBlock(module, i, &stop);
			
			if (stop)
				break;
			else
				i++;
		}
		
		[pool drain];
	};
	
	// Synchronous operation
	
	if (dispatch_get_current_queue() == xmppQueue)
		block();
	else
		dispatch_sync(xmppQueue, block);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (NSString *)generateUUID
{
	NSString *result = nil;
	
	CFUUIDRef uuid = CFUUIDCreate(NULL);
	if (uuid)
	{
		result = NSMakeCollectable(CFUUIDCreateString(NULL, uuid));
		CFRelease(uuid);
	}
	
	return [result autorelease];
}

- (NSString *)generateUUID
{
	return [[self class] generateUUID];
}

- (NSThread *)xmppUtilityThread
{
	// This is a read-only variable, set in the init method and never altered.
	// Thus we supply direct access to it in this method.
	
	return xmppUtilityThread;
}

- (NSRunLoop *)xmppUtilityRunLoop
{
	__block NSRunLoop *result = nil;
	
	dispatch_block_t block = ^{
		result = [xmppUtilityRunLoop retain];
	};
	
	if (dispatch_get_current_queue() == xmppQueue)
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	return [result autorelease];
}

- (void)setXmppUtilityRunLoop:(NSRunLoop *)runLoop
{
	dispatch_async(xmppQueue, ^{
		if (xmppUtilityRunLoop == nil)
		{
			xmppUtilityRunLoop = [runLoop retain];
		}
	});
}

+ (void)xmppThreadMain
{
	// This is the xmppUtilityThread.
	// It is designed to be used only if absolutely necessary.
	// If there is a GCD alternative, it should be used instead.
	
	NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
	
	// Set XMPPStream's xmppUtilityRunLoop variable.
	// 
	// And when done, remove the xmppStream reference from the dictionary so it's no longer retained.
	
	XMPPStream *creator = [[[NSThread currentThread] threadDictionary] objectForKey:@"XMPPStream"];
	[creator setXmppUtilityRunLoop:[NSRunLoop currentRunLoop]];
	[[[NSThread currentThread] threadDictionary] removeObjectForKey:@"XMPPStream"];
	
	// We can't iteratively run the run loop unless it has at least one source or timer.
	// So we'll create a timer that will probably never fire.
	
	[NSTimer scheduledTimerWithTimeInterval:DBL_MAX
	                                 target:self
	                               selector:@selector(xmppThreadIgnore:)
	                               userInfo:nil
	                                repeats:YES];
	
	BOOL isCancelled = NO;
	BOOL hasRunLoopSources = YES;
	
	while (!isCancelled && hasRunLoopSources)
	{
		NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
		
		hasRunLoopSources = [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
		                                             beforeDate:[NSDate distantFuture]];
		
		isCancelled = [[NSThread currentThread] isCancelled];
		[innerPool drain];
	}
	
	[outerPool drain];
}

+ (void)xmppThreadStop
{
	[[NSThread currentThread] cancel];
}

+ (void)xmppThreadIgnore:(NSTimer *)aTimer
{
	// Ignore
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPElementReceipt

- (id)init
{
	if ((self = [super init]))
	{
		atomicFlags = 0;
		semaphore = dispatch_semaphore_create(0);
	}
	return self;
}

- (void)signalSuccess
{
	uint32_t mask = 3;
	OSAtomicOr32Barrier(mask, &atomicFlags);
	
	dispatch_semaphore_signal(semaphore);
}

- (void)signalFailure
{
	uint32_t mask = 1;
	OSAtomicOr32Barrier(mask, &atomicFlags);
	
	dispatch_semaphore_signal(semaphore);
}

- (BOOL)wait:(NSTimeInterval)timeout_seconds
{
	uint32_t mask = 0;
	uint32_t flags = OSAtomicOr32Barrier(mask, &atomicFlags);
	
	if (flags > 0) return (flags > 1);
	
	dispatch_time_t timeout_nanos;
	
	if (timeout_seconds < 0.0)
		timeout_nanos = DISPATCH_TIME_NOW;
	else
		timeout_nanos = dispatch_time(DISPATCH_TIME_NOW, (timeout_seconds * NSEC_PER_SEC));
	
	// dispatch_semaphore_wait
	// 
	// Decrement the counting semaphore. If the resulting value is less than zero,
	// this function waits in FIFO order for a signal to occur before returning.
	// 
	// Returns zero on success, or non-zero if the timeout occurred.
	// 
	// Note: If the timeout occurs, the semaphore value is incremented (without signaling).
	
	long result = dispatch_semaphore_wait(semaphore, timeout_nanos);
	
	if (result == 0)
	{
		flags = OSAtomicOr32Barrier(mask, &atomicFlags);
		
		return (flags > 1);
	}
	else
	{
		return NO;
	}
}

- (void)dealloc
{
	dispatch_release(semaphore);
	
	[super dealloc];
}

@end
