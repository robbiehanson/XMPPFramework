#import "XMPP.h"
#import "XMPPParser.h"
#import "XMPPLogging.h"
#import "XMPPInternal.h"
#import "XMPPIDTracker.h"
#import "XMPPSRVResolver.h"
#import "NSData+XMPP.h"

#import <objc/runtime.h>
#import <libkern/OSAtomic.h>

#if TARGET_OS_IPHONE
  // Note: You may need to add the CFNetwork Framework to your project
  #import <CFNetwork/CFNetwork.h>
#endif

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

// Log levels: off, error, warn, info, verbose
#if DEBUG
  static const int xmppLogLevel = XMPP_LOG_LEVEL_INFO | XMPP_LOG_FLAG_SEND_RECV; // | XMPP_LOG_FLAG_TRACE;
#else
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

/**
 * Seeing a return statements within an inner block
 * can sometimes be mistaken for a return point of the enclosing method.
 * This makes inline blocks a bit easier to read.
**/
#define return_from_block  return

// Define the timeouts (in seconds) for retreiving various parts of the XML stream
#define TIMEOUT_XMPP_WRITE         -1
#define TIMEOUT_XMPP_READ_START    10
#define TIMEOUT_XMPP_READ_STREAM   -1

// Define the tags we'll use to differentiate what it is we're currently reading or writing
#define TAG_XMPP_READ_START         100
#define TAG_XMPP_READ_STREAM        101
#define TAG_XMPP_WRITE_START        200
#define TAG_XMPP_WRITE_STOP         201
#define TAG_XMPP_WRITE_STREAM       202
#define TAG_XMPP_WRITE_RECEIPT      203

// Define the timeouts (in seconds) for SRV
#define TIMEOUT_SRV_RESOLUTION 30.0

NSString *const XMPPStreamErrorDomain = @"XMPPStreamErrorDomain";
NSString *const XMPPStreamDidChangeMyJIDNotification = @"XMPPStreamDidChangeMyJID";

const NSTimeInterval XMPPStreamTimeoutNone = -1;

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

@interface XMPPStream ()
{
	dispatch_queue_t xmppQueue;
	void *xmppQueueTag;
	
	dispatch_queue_t willSendIqQueue;
	dispatch_queue_t willSendMessageQueue;
	dispatch_queue_t willSendPresenceQueue;
	
	dispatch_queue_t willReceiveStanzaQueue;
	
	dispatch_queue_t didReceiveIqQueue;
    
	dispatch_source_t connectTimer;
	
	GCDMulticastDelegate <XMPPStreamDelegate> *multicastDelegate;
	
	XMPPStreamState state;
	
	GCDAsyncSocket *asyncSocket;
	
	uint64_t numberOfBytesSent;
	uint64_t numberOfBytesReceived;
	
	XMPPParser *parser;
	NSError *parserError;
	NSError *otherError;
	
	Byte flags;
	Byte config;
	
	NSString *hostName;
	UInt16 hostPort;
    
    XMPPStreamStartTLSPolicy startTLSPolicy;
    BOOL skipStartSession;
    BOOL validatesResponses;
    BOOL preferIPv6;
	
	id <XMPPSASLAuthentication> auth;
	id <XMPPCustomBinding> customBinding;
	NSDate *authenticationDate;
	
	XMPPJID *myJID_setByClient;
	XMPPJID *myJID_setByServer;
	XMPPJID *remoteJID;
	
	XMPPPresence *myPresence;
	NSXMLElement *rootElement;
	
	NSTimeInterval keepAliveInterval;
	dispatch_source_t keepAliveTimer;
	NSTimeInterval lastSendReceiveTime;
	NSData *keepAliveData;
	
	NSMutableArray *registeredModules;
	NSMutableDictionary *autoDelegateDict;
	
	XMPPSRVResolver *srvResolver;
	NSArray *srvResults;
	NSUInteger srvResultsIndex;
    
    XMPPIDTracker *idTracker;
	
	NSMutableArray *receipts;
	NSCountedSet *customElementNames;
	
	id userTag;
}

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
@synthesize asyncSocket = asyncSocket;

/**
 * Shared initialization between the various init methods.
**/
- (void)commonInit
{
	xmppQueueTag = &xmppQueueTag;
	xmppQueue = dispatch_queue_create("xmpp", DISPATCH_QUEUE_SERIAL);
	dispatch_queue_set_specific(xmppQueue, xmppQueueTag, xmppQueueTag, NULL);
	
	willSendIqQueue = dispatch_queue_create("xmpp.willSendIq", DISPATCH_QUEUE_SERIAL);
	willSendMessageQueue = dispatch_queue_create("xmpp.willSendMessage", DISPATCH_QUEUE_SERIAL);
	willSendPresenceQueue = dispatch_queue_create("xmpp.willSendPresence", DISPATCH_QUEUE_SERIAL);
	
	didReceiveIqQueue = dispatch_queue_create("xmpp.didReceiveIq", DISPATCH_QUEUE_SERIAL);
	
	multicastDelegate = (GCDMulticastDelegate <XMPPStreamDelegate> *)[[GCDMulticastDelegate alloc] init];
	
	state = STATE_XMPP_DISCONNECTED;
	
	flags = 0;
	config = 0;
	
	numberOfBytesSent = 0;
	numberOfBytesReceived = 0;
	
	hostPort = 5222;
	keepAliveInterval = DEFAULT_KEEPALIVE_INTERVAL;
	keepAliveData = [@" " dataUsingEncoding:NSUTF8StringEncoding];
	
	registeredModules = [[NSMutableArray alloc] init];
	autoDelegateDict = [[NSMutableDictionary alloc] init];
    
    idTracker = [[XMPPIDTracker alloc] initWithStream:self dispatchQueue:xmppQueue];
	
	receipts = [[NSMutableArray alloc] init];
    preferIPv6 = YES;
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
        asyncSocket = [self newSocket];
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
		myJID_setByClient = jid;
        
        // We do not initialize the socket, since the connectP2PWithSocket: method might be used.
        
        // Initialize configuration
        config = kP2PMode;
    }
	return self;
}

/**
 * Standard deallocation method.
 * Every object variable declared in the header file should be released here.
**/
- (void)dealloc
{
	#if !OS_OBJECT_USE_OBJC
	dispatch_release(xmppQueue);
	
	dispatch_release(willSendIqQueue);
	dispatch_release(willSendMessageQueue);
	dispatch_release(willSendPresenceQueue);
	
	if (willReceiveStanzaQueue) {
		dispatch_release(willReceiveStanzaQueue);
	}
	
	dispatch_release(didReceiveIqQueue);
	#endif
	
	[asyncSocket setDelegate:nil delegateQueue:NULL];
	[asyncSocket disconnect];
	
	[parser setDelegate:nil delegateQueue:NULL];
	
	if (keepAliveTimer)
	{
		dispatch_source_cancel(keepAliveTimer);
	}
    
    [idTracker removeAllIDs];
    
	for (XMPPElementReceipt *receipt in receipts)
	{
		[receipt signalFailure];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Properties
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@synthesize xmppQueue;
@synthesize xmppQueueTag;

- (XMPPStreamState)state
{
	__block XMPPStreamState result = STATE_XMPP_DISCONNECTED;
	
	dispatch_block_t block = ^{
		result = state;
	};
	
	if (dispatch_get_specific(xmppQueueTag))
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	return result;
}

- (NSString *)hostName
{
	if (dispatch_get_specific(xmppQueueTag))
	{
		return hostName;
	}
	else
	{
		__block NSString *result;
		
		dispatch_sync(xmppQueue, ^{
			result = hostName;
		});
		
		return result;
	}
}

- (void)setHostName:(NSString *)newHostName
{
	if (dispatch_get_specific(xmppQueueTag))
	{
		if (hostName != newHostName)
		{
			hostName = [newHostName copy];
		}
	}
	else
	{
		NSString *newHostNameCopy = [newHostName copy];
		
		dispatch_async(xmppQueue, ^{
			hostName = newHostNameCopy;
		});
		
	}
}

- (UInt16)hostPort
{
	if (dispatch_get_specific(xmppQueueTag))
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
	
	if (dispatch_get_specific(xmppQueueTag))
		block();
	else
		dispatch_async(xmppQueue, block);
}

- (XMPPStreamStartTLSPolicy)startTLSPolicy
{
    __block XMPPStreamStartTLSPolicy result;
    
    dispatch_block_t block = ^{
        result = startTLSPolicy;
    };
    
    if (dispatch_get_specific(xmppQueueTag))
        block();
    else
        dispatch_sync(xmppQueue, block);
    
    return result;
}

- (void)setStartTLSPolicy:(XMPPStreamStartTLSPolicy)flag
{
	dispatch_block_t block = ^{
		startTLSPolicy = flag;
	};
	
	if (dispatch_get_specific(xmppQueueTag))
		block();
	else
		dispatch_async(xmppQueue, block);
}

- (void) setPreferIPv6:(BOOL)_preferIPv6 {
    dispatch_block_t block = ^{
        preferIPv6 = _preferIPv6;
    };
    
    if (dispatch_get_specific(xmppQueueTag))
        block();
    else
        dispatch_async(xmppQueue, block);
}

- (BOOL) preferIPv6 {
    __block BOOL result;
    dispatch_block_t block = ^{
        result = preferIPv6;
    };
    
    if (dispatch_get_specific(xmppQueueTag))
        block();
    else
        dispatch_sync(xmppQueue, block);
    return result;
}

- (XMPPJID *)myJID
{
	__block XMPPJID *result = nil;
	
	dispatch_block_t block = ^{
		
		if (myJID_setByServer)
			result = myJID_setByServer;
		else
			result = myJID_setByClient;
	};
	
	if (dispatch_get_specific(xmppQueueTag))
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	return result;
}

- (void)setMyJID_setByClient:(XMPPJID *)newMyJID
{
	// XMPPJID is an immutable class (copy == retain)
	
	dispatch_block_t block = ^{
		
		if (![myJID_setByClient isEqualToJID:newMyJID])
		{
			myJID_setByClient = newMyJID;
			
			if (myJID_setByServer == nil)
			{
				[[NSNotificationCenter defaultCenter] postNotificationName:XMPPStreamDidChangeMyJIDNotification
				                                                    object:self];
                [multicastDelegate xmppStreamDidChangeMyJID:self];
			}
		}
	};
	
	if (dispatch_get_specific(xmppQueueTag))
		block();
	else
		dispatch_async(xmppQueue, block);
}

- (void)setMyJID_setByServer:(XMPPJID *)newMyJID
{
	// XMPPJID is an immutable class (copy == retain)
	
	dispatch_block_t block = ^{
		
		if (![myJID_setByServer isEqualToJID:newMyJID])
		{
			XMPPJID *oldMyJID;
			if (myJID_setByServer)
				oldMyJID = myJID_setByServer;
			else
				oldMyJID = myJID_setByClient;
			
			myJID_setByServer = newMyJID;
			
			if (![oldMyJID isEqualToJID:newMyJID])
			{
				[[NSNotificationCenter defaultCenter] postNotificationName:XMPPStreamDidChangeMyJIDNotification
				                                                    object:self];
                [multicastDelegate xmppStreamDidChangeMyJID:self];
			}
		}
	};
	
	if (dispatch_get_specific(xmppQueueTag))
		block();
	else
		dispatch_async(xmppQueue, block);
}

- (void)setMyJID:(XMPPJID *)newMyJID
{
	[self setMyJID_setByClient:newMyJID];
}

- (XMPPJID *)remoteJID
{
	if (dispatch_get_specific(xmppQueueTag))
	{
		return remoteJID;
	}
	else
	{
		__block XMPPJID *result;
		
		dispatch_sync(xmppQueue, ^{
			result = remoteJID;
		});
		
		return result;
	}
}

- (XMPPPresence *)myPresence
{
	if (dispatch_get_specific(xmppQueueTag))
	{
		return myPresence;
	}
	else
	{
		__block XMPPPresence *result;
		
		dispatch_sync(xmppQueue, ^{
			result = myPresence;
		});
		
		return result;
	}
}

- (NSTimeInterval)keepAliveInterval
{
	__block NSTimeInterval result = 0.0;
	
	dispatch_block_t block = ^{
		result = keepAliveInterval;
	};
	
	if (dispatch_get_specific(xmppQueueTag))
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	return result;
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
	
	if (dispatch_get_specific(xmppQueueTag))
		block();
	else
		dispatch_async(xmppQueue, block);
}

- (char)keepAliveWhitespaceCharacter
{
	__block char keepAliveChar = ' ';
	
	dispatch_block_t block = ^{
		
		NSString *keepAliveString = [[NSString alloc] initWithData:keepAliveData encoding:NSUTF8StringEncoding];
		if ([keepAliveString length] > 0)
		{
			keepAliveChar = (char)[keepAliveString characterAtIndex:0];
		}
	};
	
	if (dispatch_get_specific(xmppQueueTag))
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	return keepAliveChar;
}

- (void)setKeepAliveWhitespaceCharacter:(char)keepAliveChar
{
	dispatch_block_t block = ^{
		
		if (keepAliveChar == ' ' || keepAliveChar == '\n' || keepAliveChar == '\t')
		{
			keepAliveData = [[NSString stringWithFormat:@"%c", keepAliveChar] dataUsingEncoding:NSUTF8StringEncoding];
		}
		else
		{
			XMPPLogWarn(@"Invalid whitespace character! Must be: space, newline, or tab");
		}
	};
	
	if (dispatch_get_specific(xmppQueueTag))
		block();
	else
		dispatch_async(xmppQueue, block);
}

- (uint64_t)numberOfBytesSent
{
	__block uint64_t result = 0;
	
	dispatch_block_t block = ^{
		result = numberOfBytesSent;
	};
	
	if (dispatch_get_specific(xmppQueueTag))
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	return result;
}

- (uint64_t)numberOfBytesReceived
{
	__block uint64_t result = 0;
	
	dispatch_block_t block = ^{
		result = numberOfBytesReceived;
	};
	
	if (dispatch_get_specific(xmppQueueTag))
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	return result;
}

- (void)getNumberOfBytesSent:(uint64_t *)bytesSentPtr numberOfBytesReceived:(uint64_t *)bytesReceivedPtr
{
	__block uint64_t bytesSent = 0;
	__block uint64_t bytesReceived = 0;
	
	dispatch_block_t block = ^{
		bytesSent = numberOfBytesSent;
		bytesReceived = numberOfBytesReceived;
	};
	
	if (dispatch_get_specific(xmppQueueTag))
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	if (bytesSentPtr) *bytesSentPtr = bytesSent;
	if (bytesReceivedPtr) *bytesReceivedPtr = bytesReceived;
}

- (BOOL)resetByteCountPerConnection
{
	__block BOOL result = NO;
	
	dispatch_block_t block = ^{
		result = (config & kResetByteCountPerConnection) ? YES : NO;
	};
	
	if (dispatch_get_specific(xmppQueueTag))
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
	
	if (dispatch_get_specific(xmppQueueTag))
		block();
	else
		dispatch_async(xmppQueue, block);
}

- (BOOL)skipStartSession
{
    __block BOOL result = NO;
    
    dispatch_block_t block = ^{
        result = skipStartSession;
    };
    
    if (dispatch_get_specific(xmppQueueTag))
        block();
    else
        dispatch_sync(xmppQueue, block);
    
    return result;
}

- (void)setSkipStartSession:(BOOL)flag
{
    dispatch_block_t block = ^{
        skipStartSession = flag;
    };
    
    if (dispatch_get_specific(xmppQueueTag))
        block();
    else
        dispatch_async(xmppQueue, block);
}

- (BOOL)validatesResponses
{
    __block BOOL result = NO;
    
    dispatch_block_t block = ^{
        result = validatesResponses;
    };
    
    if (dispatch_get_specific(xmppQueueTag))
        block();
    else
        dispatch_sync(xmppQueue, block);
    
    return result;
}

- (void)setValidatesResponses:(BOOL)flag
{
    dispatch_block_t block = ^{
        validatesResponses = flag;
    };
    
    if (dispatch_get_specific(xmppQueueTag))
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
	
	if (dispatch_get_specific(xmppQueueTag))
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
	
	if (dispatch_get_specific(xmppQueueTag))
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
	
	if (dispatch_get_specific(xmppQueueTag))
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
	
	if (dispatch_get_specific(xmppQueueTag))
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
	
	if (dispatch_get_specific(xmppQueueTag))
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
	if (dispatch_get_specific(xmppQueueTag))
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
	if (dispatch_get_specific(xmppQueueTag))
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
	if (dispatch_get_specific(xmppQueueTag))
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
	NSAssert(dispatch_get_specific(xmppQueueTag), @"Invoked on incorrect queue");
	
	return (flags & kDidStartNegotiation) ? YES : NO;
}

- (void)setDidStartNegotiation:(BOOL)flag
{
	NSAssert(dispatch_get_specific(xmppQueueTag), @"Invoked on incorrect queue");
	
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
	
	if (dispatch_get_specific(xmppQueueTag))
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	return result;
}

/**
 * Returns YES is the connection is currently connecting
 **/

- (BOOL)isConnecting
{
	XMPPLogTrace();
	
	__block BOOL result = NO;
	
	dispatch_block_t block = ^{ @autoreleasepool {
		result = (state == STATE_XMPP_CONNECTING);
	}};
	
	if (dispatch_get_specific(xmppQueueTag))
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
	
	if (dispatch_get_specific(xmppQueueTag))
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Connect Timeout
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Start Connect Timeout
**/
- (void)startConnectTimeout:(NSTimeInterval)timeout
{
    XMPPLogTrace();

	if (timeout >= 0.0 && !connectTimer)
	{
		connectTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, xmppQueue);
		
		dispatch_source_set_event_handler(connectTimer, ^{ @autoreleasepool {
			
			[self doConnectTimeout];
		}});
		
#if !OS_OBJECT_USE_OBJC
		dispatch_source_t theConnectTimer = connectTimer;
		dispatch_source_set_cancel_handler(connectTimer, ^{            
            XMPPLogVerbose(@"%@: dispatch_release(connectTimer)", THIS_FILE);
			dispatch_release(theConnectTimer);
		});
#endif
		
		dispatch_time_t tt = dispatch_time(DISPATCH_TIME_NOW, (timeout * NSEC_PER_SEC));
		dispatch_source_set_timer(connectTimer, tt, DISPATCH_TIME_FOREVER, 0);
		
		dispatch_resume(connectTimer);
	}
}

/**
 * End Connect Timeout
**/
- (void)endConnectTimeout
{
	XMPPLogTrace();
	
	if (connectTimer)
	{
		dispatch_source_cancel(connectTimer);
		connectTimer = NULL;
	}
}

/**
 * Connect has timed out, so inform the delegates and close the connection
**/
- (void)doConnectTimeout
{
	XMPPLogTrace();
	
	[self endConnectTimeout];
    		
    if (state != STATE_XMPP_DISCONNECTED)
    {
        [multicastDelegate xmppStreamConnectDidTimeout:self];

        if (state == STATE_XMPP_RESOLVING_SRV)
        {
            [srvResolver stop];
            srvResolver = nil;
            
            state = STATE_XMPP_DISCONNECTED;
        }
        else
        {
            [asyncSocket disconnect];
            
            // Everthing will be handled in socketDidDisconnect:withError:
        }
    }

}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark C2S Connection
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)connectToHost:(NSString *)host onPort:(UInt16)port withTimeout:(NSTimeInterval)timeout error:(NSError **)errPtr
{
	NSAssert(dispatch_get_specific(xmppQueueTag), @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	BOOL result = [asyncSocket connectToHost:host onPort:port error:errPtr];
	
	if (result && [self resetByteCountPerConnection])
	{
		numberOfBytesSent = 0;
		numberOfBytesReceived = 0;
	}
	
	if(result)
    {
        [self startConnectTimeout:timeout];
    }
	
	return result;
}

- (BOOL)connectWithTimeout:(NSTimeInterval)timeout error:(NSError **)errPtr
{
	XMPPLogTrace();
	
	__block BOOL result = NO;
	__block NSError *err = nil;
	
	dispatch_block_t block = ^{ @autoreleasepool {
	
		if (state != STATE_XMPP_DISCONNECTED)
		{
			NSString *errMsg = @"Attempting to connect while already connected or connecting.";
			NSDictionary *info = @{NSLocalizedDescriptionKey : errMsg};
			
			err = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidState userInfo:info];
			
			result = NO;
			return_from_block;
		}
		
		if ([self isP2P])
		{
			NSString *errMsg = @"P2P streams must use either connectTo:withAddress: or connectP2PWithSocket:.";
			NSDictionary *info = @{NSLocalizedDescriptionKey : errMsg};
			
			err = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidType userInfo:info];
			
			result = NO;
			return_from_block;
		}
		
		if (myJID_setByClient == nil)
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
			NSDictionary *info = @{NSLocalizedDescriptionKey : errMsg};
			
			err = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidProperty userInfo:info];
			
			result = NO;
			return_from_block;
		}

		// Notify delegates
		[multicastDelegate xmppStreamWillConnect:self];

		if ([hostName length] == 0)
		{
			// Resolve the hostName via myJID SRV resolution
			
			state = STATE_XMPP_RESOLVING_SRV;
			
			srvResolver = [[XMPPSRVResolver alloc] initWithdDelegate:self delegateQueue:xmppQueue resolverQueue:NULL];
			
			srvResults = nil;
			srvResultsIndex = 0;
			
			NSString *srvName = [XMPPSRVResolver srvNameFromXMPPDomain:[myJID_setByClient domain]];
			
			[srvResolver startWithSRVName:srvName timeout:TIMEOUT_SRV_RESOLUTION];
			
			result = YES;
		}
		else
		{
			// Open TCP connection to the configured hostName.
			
			state = STATE_XMPP_CONNECTING;
			
			NSError *connectErr = nil;
			result = [self connectToHost:hostName onPort:hostPort withTimeout:XMPPStreamTimeoutNone error:&connectErr];
			
			if (!result)
			{
				err = connectErr;
				state = STATE_XMPP_DISCONNECTED;
			}
		}
        
        if(result)
        {
            [self startConnectTimeout:timeout];
        }
	}};
	
	if (dispatch_get_specific(xmppQueueTag))
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	if (errPtr)
		*errPtr = err;
	
	return result;
}

- (BOOL)oldSchoolSecureConnectWithTimeout:(NSTimeInterval)timeout error:(NSError **)errPtr
{
	XMPPLogTrace();
	
	__block BOOL result = NO;
	__block NSError *err = nil;
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		// Go through the regular connect routine
		NSError *connectErr = nil;
		result = [self connectWithTimeout:timeout error:&connectErr];
		
		if (result)
		{
			// Mark the secure flag.
			// We will check the flag in socket:didConnectToHost:port:
			
			[self setIsSecure:YES];
		}
		else
		{
			err = connectErr;
		}
	}};
	
	if (dispatch_get_specific(xmppQueueTag))
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	if (errPtr)
		*errPtr = err;
	
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
- (BOOL)connectTo:(XMPPJID *)jid withAddress:(NSData *)remoteAddr withTimeout:(NSTimeInterval)timeout error:(NSError **)errPtr
{
	XMPPLogTrace();
	
	__block BOOL result = YES;
	__block NSError *err = nil;
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		if (state != STATE_XMPP_DISCONNECTED)
		{
			NSString *errMsg = @"Attempting to connect while already connected or connecting.";
			NSDictionary *info = @{NSLocalizedDescriptionKey : errMsg};
			
			err = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidState userInfo:info];
			
			result = NO;
			return_from_block;
		}
		
		if (![self isP2P])
		{
			NSString *errMsg = @"Non P2P streams must use the connect: method";
			NSDictionary *info = @{NSLocalizedDescriptionKey : errMsg};
			
			err = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidType userInfo:info];
			
			result = NO;
			return_from_block;
		}
		
		// Turn on P2P initiator flag
		flags |= kP2PInitiator;
		
		// Store remoteJID
		remoteJID = [jid copy];
		
		NSAssert((asyncSocket == nil), @"Forgot to release the previous asyncSocket instance.");

		// Notify delegates
		[multicastDelegate xmppStreamWillConnect:self];

		// Update state
		state = STATE_XMPP_CONNECTING;
		
		// Initailize socket
        asyncSocket = [self newSocket];
		
		NSError *connectErr = nil;
		result = [asyncSocket connectToAddress:remoteAddr error:&connectErr];
		
		if (result == NO)
		{
			err = connectErr;
			state = STATE_XMPP_DISCONNECTED;
		}
		else if ([self resetByteCountPerConnection])
		{
			numberOfBytesSent = 0;
			numberOfBytesReceived = 0;
		}
        
        if(result)
        {
            [self startConnectTimeout:timeout];
        }
	}};
	
	if (dispatch_get_specific(xmppQueueTag))
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	if (errPtr)
		*errPtr = err;
	
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
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		if (state != STATE_XMPP_DISCONNECTED)
		{
			NSString *errMsg = @"Attempting to connect while already connected or connecting.";
			NSDictionary *info = @{NSLocalizedDescriptionKey : errMsg};
			
			err = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidState userInfo:info];
			
			result = NO;
			return_from_block;
		}
		
		if (![self isP2P])
		{
			NSString *errMsg = @"Non P2P streams must use the connect: method";
			NSDictionary *info = @{NSLocalizedDescriptionKey : errMsg};
			
			err = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidType userInfo:info];
			
			result = NO;
			return_from_block;
		}
		
		if (acceptedSocket == nil)
		{
			NSString *errMsg = @"Parameter acceptedSocket is nil.";
			NSDictionary *info = @{NSLocalizedDescriptionKey : errMsg};
			
			err = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidParameter userInfo:info];
			
			result = NO;
			return_from_block;
		}
		
		// Turn off P2P initiator flag
		flags &= ~kP2PInitiator;
		
		NSAssert((asyncSocket == nil), @"Forgot to release the previous asyncSocket instance.");
		
		// Store and configure socket
		asyncSocket = acceptedSocket;
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
	}};
	
	if (dispatch_get_specific(xmppQueueTag))
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	if (errPtr)
		*errPtr = err;
	
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
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		if (state != STATE_XMPP_DISCONNECTED)
		{
			[multicastDelegate xmppStreamWasToldToDisconnect:self];
			
			if (state == STATE_XMPP_RESOLVING_SRV)
			{
				[srvResolver stop];
				srvResolver = nil;
				
				state = STATE_XMPP_DISCONNECTED;
				
				[multicastDelegate xmppStreamDidDisconnect:self withError:nil];
			}
			else
			{
				[asyncSocket disconnect];
				
				// Everthing will be handled in socketDidDisconnect:withError:
			}
		}
	}};
	
	if (dispatch_get_specific(xmppQueueTag))
		block();
	else
		dispatch_sync(xmppQueue, block);
}

- (void)disconnectAfterSending
{
	XMPPLogTrace();
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		if (state != STATE_XMPP_DISCONNECTED)
		{
			[multicastDelegate xmppStreamWasToldToDisconnect:self];
			
			if (state == STATE_XMPP_RESOLVING_SRV)
			{
				[srvResolver stop];
				srvResolver = nil;
				
				state = STATE_XMPP_DISCONNECTED;
				
				[multicastDelegate xmppStreamDidDisconnect:self withError:nil];
			}
			else
			{
				NSString *termStr = @"</stream:stream>";
				NSData *termData = [termStr dataUsingEncoding:NSUTF8StringEncoding];
				
				XMPPLogSend(@"SEND: %@", termStr);
				numberOfBytesSent += [termData length];
				
				[asyncSocket writeData:termData withTimeout:TIMEOUT_XMPP_WRITE tag:TAG_XMPP_WRITE_STOP];
				[asyncSocket disconnectAfterWriting];
				
				// Everthing will be handled in socketDidDisconnect:withError:
			}
		}
	}};
	
	if (dispatch_get_specific(xmppQueueTag))
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
	if (dispatch_get_specific(xmppQueueTag))
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
	
	if (dispatch_get_specific(xmppQueueTag))
		block();
	else
		dispatch_async(xmppQueue, block);
}

- (BOOL)supportsStartTLS
{
	__block BOOL result = NO;
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		// The root element can be properly queried for authentication mechanisms anytime after the
		// stream:features are received, and TLS has been setup (if required)
		if (state >= STATE_XMPP_POST_NEGOTIATION)
		{
			NSXMLElement *features = [rootElement elementForName:@"stream:features"];
			NSXMLElement *starttls = [features elementForName:@"starttls" xmlns:@"urn:ietf:params:xml:ns:xmpp-tls"];
			
			result = (starttls != nil);
		}
	}};
	
	if (dispatch_get_specific(xmppQueueTag))
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	return result;
}

- (void)sendStartTLSRequest
{
	NSAssert(dispatch_get_specific(xmppQueueTag), @"Invoked on incorrect queue");
	
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
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		if (state != STATE_XMPP_CONNECTED)
		{
			NSString *errMsg = @"Please wait until the stream is connected.";
			NSDictionary *info = @{NSLocalizedDescriptionKey : errMsg};
			
			err = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidState userInfo:info];
			
			result = NO;
			return_from_block;
		}
		
		if ([self isSecure])
		{
			NSString *errMsg = @"The connection is already secure.";
			NSDictionary *info = @{NSLocalizedDescriptionKey : errMsg};
			
			err = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidState userInfo:info];
			
			result = NO;
			return_from_block;
		}
		
		if (![self supportsStartTLS])
		{
			NSString *errMsg = @"The server does not support startTLS.";
			NSDictionary *info = @{NSLocalizedDescriptionKey : errMsg};
			
			err = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamUnsupportedAction userInfo:info];
			
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
		
	}};
	
	if (dispatch_get_specific(xmppQueueTag))
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	if (errPtr)
		*errPtr = err;
	
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
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		// The root element can be properly queried for authentication mechanisms anytime after the
		// stream:features are received, and TLS has been setup (if required)
		if (state >= STATE_XMPP_POST_NEGOTIATION)
		{
			NSXMLElement *features = [rootElement elementForName:@"stream:features"];
			NSXMLElement *reg = [features elementForName:@"register" xmlns:@"http://jabber.org/features/iq-register"];
			
			result = (reg != nil);
		}
	}};
	
	if (dispatch_get_specific(xmppQueueTag))
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	return result;
}

/**
 * This method attempts to register a new user on the server using the given elements.
 * The result of this action will be returned via the delegate methods.
 *
 * If the XMPPStream is not connected, or the server doesn't support in-band registration, this method does nothing.
**/
- (BOOL)registerWithElements:(NSArray *)elements error:(NSError **)errPtr
{
    XMPPLogTrace();
	
	__block BOOL result = YES;
	__block NSError *err = nil;
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		if (state != STATE_XMPP_CONNECTED)
		{
			NSString *errMsg = @"Please wait until the stream is connected.";
			NSDictionary *info = @{NSLocalizedDescriptionKey : errMsg};
			
			err = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidState userInfo:info];
			
			result = NO;
			return_from_block;
		}
		
		if (![self supportsInBandRegistration])
		{
			NSString *errMsg = @"The server does not support in band registration.";
			NSDictionary *info = @{NSLocalizedDescriptionKey : errMsg};
			
			err = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamUnsupportedAction userInfo:info];
			
			result = NO;
			return_from_block;
		}
        
		NSXMLElement *queryElement = [NSXMLElement elementWithName:@"query" xmlns:@"jabber:iq:register"];
        
        for(NSXMLElement *element in elements)
        {
            [queryElement addChild:element];
        }
		
		XMPPIQ *iq = [XMPPIQ iqWithType:@"set"];
		[iq addChild:queryElement];
		
		NSString *outgoingStr = [iq compactXMLString];
		NSData *outgoingData = [outgoingStr dataUsingEncoding:NSUTF8StringEncoding];
		
		XMPPLogSend(@"SEND: %@", outgoingStr);
		numberOfBytesSent += [outgoingData length];
		
		[asyncSocket writeData:outgoingData
		           withTimeout:TIMEOUT_XMPP_WRITE
		                   tag:TAG_XMPP_WRITE_STREAM];
		
		// Update state
		state = STATE_XMPP_REGISTERING;
		
	}};
	
	if (dispatch_get_specific(xmppQueueTag))
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	if (errPtr)
		*errPtr = err;
	
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
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		if (myJID_setByClient == nil)
		{
			NSString *errMsg = @"You must set myJID before calling registerWithPassword:error:.";
			NSDictionary *info = @{NSLocalizedDescriptionKey : errMsg};
			
			err = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidProperty userInfo:info];
			
			result = NO;
			return_from_block;
		}
		
		NSString *username = [myJID_setByClient user];
		
		NSMutableArray *elements = [NSMutableArray array];
		[elements addObject:[NSXMLElement elementWithName:@"username" stringValue:username]];
		[elements addObject:[NSXMLElement elementWithName:@"password" stringValue:password]];
        
        [self registerWithElements:elements error:errPtr];
        
	}};
	
	if (dispatch_get_specific(xmppQueueTag))
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	if (errPtr)
		*errPtr = err;
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Authentication
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSArray *)supportedAuthenticationMechanisms
{
	__block NSMutableArray *result = [[NSMutableArray alloc] init];
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		// The root element can be properly queried for authentication mechanisms anytime after the
		// stream:features are received, and TLS has been setup (if required).
		
		if (state >= STATE_XMPP_POST_NEGOTIATION)
		{
			NSXMLElement *features = [rootElement elementForName:@"stream:features"];
			NSXMLElement *mech = [features elementForName:@"mechanisms" xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
			
			NSArray *mechanisms = [mech elementsForName:@"mechanism"];
			
			for (NSXMLElement *mechanism in mechanisms)
			{
				[result addObject:[mechanism stringValue]];
			}
		}
	}};
	
	if (dispatch_get_specific(xmppQueueTag))
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	return result;
}

/**
 * This method checks the stream features of the connected server to determine
 * if the given authentication mechanism is supported.
 * 
 * If we are not connected to a server, this method simply returns NO.
**/
- (BOOL)supportsAuthenticationMechanism:(NSString *)mechanismType
{
	__block BOOL result = NO;
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		// The root element can be properly queried for authentication mechanisms anytime after the
		// stream:features are received, and TLS has been setup (if required).
		
		if (state >= STATE_XMPP_POST_NEGOTIATION)
		{
			NSXMLElement *features = [rootElement elementForName:@"stream:features"];
			NSXMLElement *mech = [features elementForName:@"mechanisms" xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
			
			NSArray *mechanisms = [mech elementsForName:@"mechanism"];
			
			for (NSXMLElement *mechanism in mechanisms)
			{
				if ([[mechanism stringValue] isEqualToString:mechanismType])
				{
					result = YES;
					break;
				}
			}
		}
	}};
	
	if (dispatch_get_specific(xmppQueueTag))
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	return result;
}

- (BOOL)authenticate:(id <XMPPSASLAuthentication>)inAuth error:(NSError **)errPtr
{
	XMPPLogTrace();
	
	__block BOOL result = NO;
	__block NSError *err = nil;
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		if (state != STATE_XMPP_CONNECTED)
		{
			NSString *errMsg = @"Please wait until the stream is connected.";
			NSDictionary *info = @{NSLocalizedDescriptionKey : errMsg};
			
			err = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidState userInfo:info];
			
			result = NO;
			return_from_block;
		}
		
		if (myJID_setByClient == nil)
		{
			NSString *errMsg = @"You must set myJID before calling authenticate:error:.";
			NSDictionary *info = @{NSLocalizedDescriptionKey : errMsg};
			
			err = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidProperty userInfo:info];
			
			result = NO;
			return_from_block;
		}
		
		// Change state.
		// We do this now because when we invoke the start method below,
		// it may in turn invoke our sendAuthElement method, which expects us to be in STATE_XMPP_AUTH.
		state = STATE_XMPP_AUTH;
		
		if ([inAuth start:&err])
		{
			auth = inAuth;
			result = YES;
		}
		else
		{
			// Unable to start authentication for some reason.
			// Revert back to connected state.
			state = STATE_XMPP_CONNECTED;
		}
	}};
	
	if (dispatch_get_specific(xmppQueueTag))
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	if (errPtr)
		*errPtr = err;
	
	return result;
}

/**
 * This method applies to standard password authentication schemes only.
 * This is NOT the primary authentication method.
 * 
 * @see authenticate:error:
 * 
 * This method exists for backwards compatibility, and may disappear in future versions.
**/
- (BOOL)authenticateWithPassword:(NSString *)inPassword error:(NSError **)errPtr
{
	XMPPLogTrace();
	
	// The given password parameter could be mutable
	NSString *password = [inPassword copy];
	
	
	__block BOOL result = YES;
	__block NSError *err = nil;
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		if (state != STATE_XMPP_CONNECTED)
		{
			NSString *errMsg = @"Please wait until the stream is connected.";
			NSDictionary *info = @{NSLocalizedDescriptionKey : errMsg};
			
			err = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidState userInfo:info];
			
			result = NO;
			return_from_block;
		}
		
		if (myJID_setByClient == nil)
		{
			NSString *errMsg = @"You must set myJID before calling authenticate:error:.";
			NSDictionary *info = @{NSLocalizedDescriptionKey : errMsg};
			
			err = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidProperty userInfo:info];
			
			result = NO;
			return_from_block;
		}
		
		// Choose the best authentication method.
		// 
		// P.S. - This method is deprecated.
		
		id <XMPPSASLAuthentication> someAuth = nil;
        
		if ([self supportsSCRAMSHA1Authentication])
		{
			someAuth = [[XMPPSCRAMSHA1Authentication alloc] initWithStream:self password:password];
			result = [self authenticate:someAuth error:&err];
		}
		else if ([self supportsDigestMD5Authentication])
		{
			someAuth = [[XMPPDigestMD5Authentication alloc] initWithStream:self password:password];
			result = [self authenticate:someAuth error:&err];
		}
		else if ([self supportsPlainAuthentication])
		{
			someAuth = [[XMPPPlainAuthentication alloc] initWithStream:self password:password];
			result = [self authenticate:someAuth error:&err];
		}
		else if ([self supportsDeprecatedDigestAuthentication])
		{
			someAuth = [[XMPPDeprecatedDigestAuthentication alloc] initWithStream:self password:password];
			result = [self authenticate:someAuth error:&err];
		}
		else if ([self supportsDeprecatedPlainAuthentication])
		{
			someAuth = [[XMPPDeprecatedDigestAuthentication alloc] initWithStream:self password:password];
			result = [self authenticate:someAuth error:&err];
		}
		else
		{
			NSString *errMsg = @"No suitable authentication method found";
			NSDictionary *info = @{NSLocalizedDescriptionKey : errMsg};
			
			err = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamUnsupportedAction userInfo:info];
			
			result = NO;
		}
	}};
	
	
	if (dispatch_get_specific(xmppQueueTag))
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	if (errPtr)
		*errPtr = err;
	
	return result;
}

- (BOOL)isAuthenticating
{		
	__block BOOL result = NO;
	
	dispatch_block_t block = ^{ @autoreleasepool {
		result = (state == STATE_XMPP_AUTH);
	}};
	
	if (dispatch_get_specific(xmppQueueTag))
		block();
	else
		dispatch_sync(xmppQueue, block);

	return result;
}

- (BOOL)isAuthenticated
{
	__block BOOL result = NO;
	
	dispatch_block_t block = ^{
		result = (flags & kIsAuthenticated) ? YES : NO;
	};
	
	if (dispatch_get_specific(xmppQueueTag))
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	return result;
}

- (void)setIsAuthenticated:(BOOL)flag
{
	dispatch_block_t block = ^{
		if(flag)
		{
			flags |= kIsAuthenticated;
			authenticationDate = [NSDate date];
		}
		else
		{
			flags &= ~kIsAuthenticated;
			authenticationDate = nil;
		}
	};
	
	if (dispatch_get_specific(xmppQueueTag))
		block();
	else
		dispatch_async(xmppQueue, block);
}

- (NSDate *)authenticationDate
{
	__block NSDate *result = nil;
	
	dispatch_block_t block = ^{
		if(flags & kIsAuthenticated)
		{
			result =  authenticationDate;
		}
	};
	
	if (dispatch_get_specific(xmppQueueTag))
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Compression
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSArray *)supportedCompressionMethods
{
	__block NSMutableArray *result = [[NSMutableArray alloc] init];
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		// The root element can be properly queried for compression methods anytime after the
		// stream:features are received, and TLS has been setup (if required).
		
		if (state >= STATE_XMPP_POST_NEGOTIATION)
		{
			NSXMLElement *features = [rootElement elementForName:@"stream:features"];
			NSXMLElement *compression = [features elementForName:@"compression" xmlns:@"http://jabber.org/features/compress"];
			
			NSArray *methods = [compression elementsForName:@"method"];
			
			for (NSXMLElement *method in methods)
			{
				[result addObject:[method stringValue]];
			}
		}
	}};
	
	if (dispatch_get_specific(xmppQueueTag))
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	return result;
}

/**
 * This method checks the stream features of the connected server to determine
 * if the given compression method is supported.
 *
 * If we are not connected to a server, this method simply returns NO.
**/
- (BOOL)supportsCompressionMethod:(NSString *)compressionMethod
{
	__block BOOL result = NO;
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		// The root element can be properly queried for compression methods anytime after the
		// stream:features are received, and TLS has been setup (if required).
		
		if (state >= STATE_XMPP_POST_NEGOTIATION)
		{
			NSXMLElement *features = [rootElement elementForName:@"stream:features"];
			NSXMLElement *compression = [features elementForName:@"compression" xmlns:@"http://jabber.org/features/compress"];
			
			NSArray *methods = [compression elementsForName:@"method"];
			
			for (NSXMLElement *method in methods)
			{
				if ([[method stringValue] isEqualToString:compressionMethod])
				{
					result = YES;
					break;
				}
			}
		}
	}};
	
	if (dispatch_get_specific(xmppQueueTag))
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	return result;
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
	if (dispatch_get_specific(xmppQueueTag))
	{
		return rootElement;
	}
	else
	{
		__block NSXMLElement *result = nil;
		
		dispatch_sync(xmppQueue, ^{
			result = [rootElement copy];
		});
		
		return result;
	}
}

/**
 * Returns the version attribute from the servers's <stream:stream/> element.
 * This should be at least 1.0 to be RFC 3920 compliant.
 * If no version number was set, the server is not RFC compliant, and 0 is returned.
**/
- (float)serverXmppStreamVersionNumber
{
	if (dispatch_get_specific(xmppQueueTag))
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
	NSAssert(dispatch_get_specific(xmppQueueTag), @"Invoked on incorrect queue");
	NSAssert(state == STATE_XMPP_CONNECTED, @"Invoked with incorrect state");
	
	// We're getting ready to send an IQ.
	// Notify delegates to allow them to optionally alter/filter the outgoing IQ.
	
	SEL selector = @selector(xmppStream:willSendIQ:);
	
	if (![multicastDelegate hasDelegateThatRespondsToSelector:selector])
	{
		// None of the delegates implement the method.
		// Use a shortcut.
		
		[self continueSendIQ:iq withTag:tag];
	}
	else
	{
		// Notify all interested delegates.
		// This must be done serially to allow them to alter the element in a thread-safe manner.
		
		GCDMulticastDelegateEnumerator *delegateEnumerator = [multicastDelegate delegateEnumerator];
		
		dispatch_async(willSendIqQueue, ^{ @autoreleasepool {
			
			// Allow delegates to modify and/or filter outgoing element
			
			__block XMPPIQ *modifiedIQ = iq;
			
			id del;
			dispatch_queue_t dq;
			
			while (modifiedIQ && [delegateEnumerator getNextDelegate:&del delegateQueue:&dq forSelector:selector])
			{
				#if DEBUG
				{
					char methodReturnType[32];
				
					Method method = class_getInstanceMethod([del class], selector);
					method_getReturnType(method, methodReturnType, sizeof(methodReturnType));
				
					if (strcmp(methodReturnType, @encode(XMPPIQ*)) != 0)
					{
						NSAssert(NO, @"Method xmppStream:willSendIQ: is no longer void (see XMPPStream.h). "
						             @"Culprit = %@", NSStringFromClass([del class]));
					}
				}
				#endif
				
				dispatch_sync(dq, ^{ @autoreleasepool {
					
					modifiedIQ = [del xmppStream:self willSendIQ:modifiedIQ];
					
				}});
			}
			
			if (modifiedIQ)
			{
				dispatch_async(xmppQueue, ^{ @autoreleasepool {
					
					if (state == STATE_XMPP_CONNECTED) {
						[self continueSendIQ:modifiedIQ withTag:tag];
					} else {
						[self failToSendIQ:modifiedIQ];
					}
				}});
			}
		}});
	}
}

- (void)sendMessage:(XMPPMessage *)message withTag:(long)tag
{
	NSAssert(dispatch_get_specific(xmppQueueTag), @"Invoked on incorrect queue");
	NSAssert(state == STATE_XMPP_CONNECTED, @"Invoked with incorrect state");
	
	// We're getting ready to send a message.
	// Notify delegates to allow them to optionally alter/filter the outgoing message.
	
	SEL selector = @selector(xmppStream:willSendMessage:);
	
	if (![multicastDelegate hasDelegateThatRespondsToSelector:selector])
	{
		// None of the delegates implement the method.
		// Use a shortcut.
		
		[self continueSendMessage:message withTag:tag];
	}
	else
	{
		// Notify all interested delegates.
		// This must be done serially to allow them to alter the element in a thread-safe manner.
		
		GCDMulticastDelegateEnumerator *delegateEnumerator = [multicastDelegate delegateEnumerator];
		
		dispatch_async(willSendMessageQueue, ^{ @autoreleasepool {
			
			// Allow delegates to modify outgoing element
			
			__block XMPPMessage *modifiedMessage = message;
			
			id del;
			dispatch_queue_t dq;
			
			while (modifiedMessage && [delegateEnumerator getNextDelegate:&del delegateQueue:&dq forSelector:selector])
			{
				#if DEBUG
				{
					char methodReturnType[32];
				
					Method method = class_getInstanceMethod([del class], selector);
					method_getReturnType(method, methodReturnType, sizeof(methodReturnType));
				
					if (strcmp(methodReturnType, @encode(XMPPMessage*)) != 0)
					{
						NSAssert(NO, @"Method xmppStream:willSendMessage: is no longer void (see XMPPStream.h). "
						             @"Culprit = %@", NSStringFromClass([del class]));
					}
				}
				#endif
				
				dispatch_sync(dq, ^{ @autoreleasepool {
					
					modifiedMessage = [del xmppStream:self willSendMessage:modifiedMessage];
					
				}});
			}
			
			if (modifiedMessage)
			{
				dispatch_async(xmppQueue, ^{ @autoreleasepool {
					
					if (state == STATE_XMPP_CONNECTED) {
						[self continueSendMessage:modifiedMessage withTag:tag];
					}
					else {
						[self failToSendMessage:modifiedMessage];
					}
				}});
			}
		}});
	}
}

- (void)sendPresence:(XMPPPresence *)presence withTag:(long)tag
{
	NSAssert(dispatch_get_specific(xmppQueueTag), @"Invoked on incorrect queue");
	NSAssert(state == STATE_XMPP_CONNECTED, @"Invoked with incorrect state");
	
	// We're getting ready to send a presence element.
	// Notify delegates to allow them to optionally alter/filter the outgoing presence.
	
	SEL selector = @selector(xmppStream:willSendPresence:);
	
	if (![multicastDelegate hasDelegateThatRespondsToSelector:selector])
	{
		// None of the delegates implement the method.
		// Use a shortcut.
		
		[self continueSendPresence:presence withTag:tag];
	}
	else
	{
		// Notify all interested delegates.
		// This must be done serially to allow them to alter the element in a thread-safe manner.
		
		GCDMulticastDelegateEnumerator *delegateEnumerator = [multicastDelegate delegateEnumerator];
		
		dispatch_async(willSendPresenceQueue, ^{ @autoreleasepool {
			
			// Allow delegates to modify outgoing element
			
			__block XMPPPresence *modifiedPresence = presence;
			
			id del;
			dispatch_queue_t dq;
			
			while (modifiedPresence && [delegateEnumerator getNextDelegate:&del delegateQueue:&dq forSelector:selector])
			{
				#if DEBUG
				{
					char methodReturnType[32];
				
					Method method = class_getInstanceMethod([del class], selector);
					method_getReturnType(method, methodReturnType, sizeof(methodReturnType));
				
					if (strcmp(methodReturnType, @encode(XMPPPresence*)) != 0)
					{
						NSAssert(NO, @"Method xmppStream:willSendPresence: is no longer void (see XMPPStream.h). "
						             @"Culprit = %@", NSStringFromClass([del class]));
					}
				}
				#endif
				
				dispatch_sync(dq, ^{ @autoreleasepool {
					
					modifiedPresence = [del xmppStream:self willSendPresence:modifiedPresence];
					
				}});
			}
			
			if (modifiedPresence)
			{
				dispatch_async(xmppQueue, ^{ @autoreleasepool {
					
					if (state == STATE_XMPP_CONNECTED) {
						[self continueSendPresence:modifiedPresence withTag:tag];
					} else {
						[self failToSendPresence:modifiedPresence];
					}
				}});
			}
		}});
	}
}

- (void)continueSendIQ:(XMPPIQ *)iq withTag:(long)tag
{
	NSAssert(dispatch_get_specific(xmppQueueTag), @"Invoked on incorrect queue");
	NSAssert(state == STATE_XMPP_CONNECTED, @"Invoked with incorrect state");
	
	NSString *outgoingStr = [iq compactXMLString];
	NSData *outgoingData = [outgoingStr dataUsingEncoding:NSUTF8StringEncoding];
	
	XMPPLogSend(@"SEND: %@", outgoingStr);
	numberOfBytesSent += [outgoingData length];
	
	[asyncSocket writeData:outgoingData
	           withTimeout:TIMEOUT_XMPP_WRITE
	                   tag:tag];
	
	[multicastDelegate xmppStream:self didSendIQ:iq];
}

- (void)continueSendMessage:(XMPPMessage *)message withTag:(long)tag
{
	NSAssert(dispatch_get_specific(xmppQueueTag), @"Invoked on incorrect queue");
	NSAssert(state == STATE_XMPP_CONNECTED, @"Invoked with incorrect state");
	
	NSString *outgoingStr = [message compactXMLString];
	NSData *outgoingData = [outgoingStr dataUsingEncoding:NSUTF8StringEncoding];
	
	XMPPLogSend(@"SEND: %@", outgoingStr);
	numberOfBytesSent += [outgoingData length];
	
	[asyncSocket writeData:outgoingData
	           withTimeout:TIMEOUT_XMPP_WRITE
	                   tag:tag];
	
	[multicastDelegate xmppStream:self didSendMessage:message];
}

- (void)continueSendPresence:(XMPPPresence *)presence withTag:(long)tag
{
	NSAssert(dispatch_get_specific(xmppQueueTag), @"Invoked on incorrect queue");
	NSAssert(state == STATE_XMPP_CONNECTED, @"Invoked with incorrect state");
	
	NSString *outgoingStr = [presence compactXMLString];
	NSData *outgoingData = [outgoingStr dataUsingEncoding:NSUTF8StringEncoding];
	
	XMPPLogSend(@"SEND: %@", outgoingStr);
	numberOfBytesSent += [outgoingData length];
	
	[asyncSocket writeData:outgoingData
	           withTimeout:TIMEOUT_XMPP_WRITE
	                   tag:tag];
	
	// Update myPresence if this is a normal presence element.
	// In other words, ignore presence subscription stuff, MUC room stuff, etc.
	// 
	// We use the built-in [presence type] which guarantees lowercase strings,
	// and will return @"available" if there was no set type (as available is implicit).
	
	NSString *type = [presence type];
	if ([type isEqualToString:@"available"] || [type isEqualToString:@"unavailable"])
	{
		if ([presence toStr] == nil && myPresence != presence)
		{
			myPresence = presence;
		}
	}
	
	[multicastDelegate xmppStream:self didSendPresence:presence];
}

- (void)continueSendElement:(NSXMLElement *)element withTag:(long)tag
{
	NSAssert(dispatch_get_specific(xmppQueueTag), @"Invoked on incorrect queue");
	NSAssert(state == STATE_XMPP_CONNECTED, @"Invoked with incorrect state");
	
	NSString *outgoingStr = [element compactXMLString];
	NSData *outgoingData = [outgoingStr dataUsingEncoding:NSUTF8StringEncoding];
	
	XMPPLogSend(@"SEND: %@", outgoingStr);
	numberOfBytesSent += [outgoingData length];
	
	[asyncSocket writeData:outgoingData
	           withTimeout:TIMEOUT_XMPP_WRITE
	                   tag:tag];
	
	if ([customElementNames countForObject:[element name]])
	{
		[multicastDelegate xmppStream:self didSendCustomElement:element];
	}
}

/**
 * Private method.
 * Presencts a common method for the various public sendElement methods.
**/
- (void)sendElement:(NSXMLElement *)element withTag:(long)tag
{
	NSAssert(dispatch_get_specific(xmppQueueTag), @"Invoked on incorrect queue");
	
	
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
		else
		{
			[self continueSendElement:element withTag:tag];
		}
	}
}

/**
 * This method handles sending an XML stanza.
 * If the XMPPStream is not connected, this method does nothing.
**/
- (void)sendElement:(NSXMLElement *)element
{
	if (element == nil) return;
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		if (state == STATE_XMPP_CONNECTED)
		{
			[self sendElement:element withTag:TAG_XMPP_WRITE_STREAM];
		}
		else
		{
			[self failToSendElement:element];
		}
	}};
	
	if (dispatch_get_specific(xmppQueueTag))
		block();
	else
		dispatch_async(xmppQueue, block);
}

/**
 * This method handles sending an XML stanza.
 * If the XMPPStream is not connected, this method does nothing.
 * 
 * After the element has been successfully sent,
 * the xmppStream:didSendElementWithTag: delegate method is called.
**/
- (void)sendElement:(NSXMLElement *)element andGetReceipt:(XMPPElementReceipt **)receiptPtr
{
	if (element == nil) return;
	
	if (receiptPtr == nil)
	{
		[self sendElement:element];
	}
	else
	{
		__block XMPPElementReceipt *receipt = nil;
		
		dispatch_block_t block = ^{ @autoreleasepool {
			
			if (state == STATE_XMPP_CONNECTED)
			{
				receipt = [[XMPPElementReceipt alloc] init];
				[receipts addObject:receipt];
				
				[self sendElement:element withTag:TAG_XMPP_WRITE_RECEIPT];
			}
            else
            {
                [self failToSendElement:element];
            }
		}};
		
		if (dispatch_get_specific(xmppQueueTag))
			block();
		else
			dispatch_sync(xmppQueue, block);
		
		*receiptPtr = receipt;
	}
}

- (void)failToSendElement:(NSXMLElement *)element
{
	NSAssert(dispatch_get_specific(xmppQueueTag), @"Invoked on incorrect queue");
	
	if ([element isKindOfClass:[XMPPIQ class]])
	{
		[self failToSendIQ:(XMPPIQ *)element];
	}
	else if ([element isKindOfClass:[XMPPMessage class]])
	{
		[self failToSendMessage:(XMPPMessage *)element];
	}
	else if ([element isKindOfClass:[XMPPPresence class]])
	{
		[self failToSendPresence:(XMPPPresence *)element];
	}
	else
	{
		NSString *elementName = [element name];
		
		if ([elementName isEqualToString:@"iq"])
		{
			[self failToSendIQ:[XMPPIQ iqFromElement:element]];
		}
		else if ([elementName isEqualToString:@"message"])
		{
			[self failToSendMessage:[XMPPMessage messageFromElement:element]];
		}
		else if ([elementName isEqualToString:@"presence"])
		{
			[self failToSendPresence:[XMPPPresence presenceFromElement:element]];
		}
	}
}

- (void)failToSendIQ:(XMPPIQ *)iq
{
	NSAssert(dispatch_get_specific(xmppQueueTag), @"Invoked on incorrect queue");
	
	NSError *error = [NSError errorWithDomain:XMPPStreamErrorDomain
	                                     code:XMPPStreamInvalidState
	                                 userInfo:nil];
	
	[multicastDelegate xmppStream:self didFailToSendIQ:iq error:error];
}

- (void)failToSendMessage:(XMPPMessage *)message
{
	NSAssert(dispatch_get_specific(xmppQueueTag), @"Invoked on incorrect queue");
	
	NSError *error = [NSError errorWithDomain:XMPPStreamErrorDomain
	                                     code:XMPPStreamInvalidState
	                                 userInfo:nil];
	
	[multicastDelegate xmppStream:self didFailToSendMessage:message error:error];
}

- (void)failToSendPresence:(XMPPPresence *)presence
{
	NSAssert(dispatch_get_specific(xmppQueueTag), @"Invoked on incorrect queue");
	
	NSError *error = [NSError errorWithDomain:XMPPStreamErrorDomain
	                                     code:XMPPStreamInvalidState
	                                 userInfo:nil];
	
	[multicastDelegate xmppStream:self didFailToSendPresence:presence error:error];
}

/**
 * Retrieves the current presence and resends it in once atomic operation.
 * Useful for various components that need to update injected information in the presence stanza.
**/
- (void)resendMyPresence
{
	dispatch_block_t block = ^{ @autoreleasepool {
		
		if (myPresence && [[myPresence type] isEqualToString:@"available"])
		{
			[self sendElement:myPresence];
		}
	}};
	
	if (dispatch_get_specific(xmppQueueTag))
		block();
	else
		dispatch_async(xmppQueue, block);
}

/**
 * This method is for use by xmpp authentication mechanism classes.
 * They should send elements using this method instead of the public sendElement methods,
 * as those methods don't send the elements while authentication is in progress.
 *
 * @see XMPPSASLAuthentication
**/
- (void)sendAuthElement:(NSXMLElement *)element
{
	dispatch_block_t block = ^{ @autoreleasepool {
		
		if (state == STATE_XMPP_AUTH)
		{
			NSString *outgoingStr = [element compactXMLString];
			NSData *outgoingData = [outgoingStr dataUsingEncoding:NSUTF8StringEncoding];
			
			XMPPLogSend(@"SEND: %@", outgoingStr);
			numberOfBytesSent += [outgoingData length];
			
			[asyncSocket writeData:outgoingData
			           withTimeout:TIMEOUT_XMPP_WRITE
			                   tag:TAG_XMPP_WRITE_STREAM];
		}
		else
		{
			XMPPLogWarn(@"Unable to send element while not in STATE_XMPP_AUTH: %@", [element compactXMLString]);
		}
	}};
	
	if (dispatch_get_specific(xmppQueueTag))
		block();
	else
		dispatch_async(xmppQueue, block);
}

/**
 * This method is for use by xmpp custom binding classes.
 * They should send elements using this method instead of the public sendElement methods,
 * as those methods don't send the elements while authentication/binding is in progress.
 *
 * @see XMPPCustomBinding
**/
- (void)sendBindElement:(NSXMLElement *)element
{
	dispatch_block_t block = ^{ @autoreleasepool {
		
		if (state == STATE_XMPP_BINDING)
		{
			NSString *outgoingStr = [element compactXMLString];
			NSData *outgoingData = [outgoingStr dataUsingEncoding:NSUTF8StringEncoding];
			
			XMPPLogSend(@"SEND: %@", outgoingStr);
			numberOfBytesSent += [outgoingData length];
			
			[asyncSocket writeData:outgoingData
			           withTimeout:TIMEOUT_XMPP_WRITE
			                   tag:TAG_XMPP_WRITE_STREAM];
		}
		else
		{
			XMPPLogWarn(@"Unable to send element while not in STATE_XMPP_BINDING: %@", [element compactXMLString]);
		}
	}};
	
	if (dispatch_get_specific(xmppQueueTag))
		block();
	else
		dispatch_async(xmppQueue, block);
}

- (void)receiveIQ:(XMPPIQ *)iq
{
	NSAssert(dispatch_get_specific(xmppQueueTag), @"Invoked on incorrect queue");
	NSAssert(state == STATE_XMPP_CONNECTED, @"Invoked with incorrect state");
	
	// We're getting ready to receive an IQ.
	// Notify delegates to allow them to optionally alter/filter the incoming IQ element.
	
	SEL selector = @selector(xmppStream:willReceiveIQ:);
	
	if (![multicastDelegate hasDelegateThatRespondsToSelector:selector])
	{
		// None of the delegates implement the method.
		// Use a shortcut.
		
		if (willReceiveStanzaQueue)
		{
			// But still go through the stanzaQueue in order to guarantee in-order-delivery of all received stanzas.
			
			dispatch_async(willReceiveStanzaQueue, ^{
				dispatch_async(xmppQueue, ^{ @autoreleasepool {
					if (state == STATE_XMPP_CONNECTED) {
						[self continueReceiveIQ:iq];
					}
				}});
			});
		}
		else
		{
			[self continueReceiveIQ:iq];
		}
	}
	else
	{
		// Notify all interested delegates.
		// This must be done serially to allow them to alter the element in a thread-safe manner.
		
		GCDMulticastDelegateEnumerator *delegateEnumerator = [multicastDelegate delegateEnumerator];
		
		if (willReceiveStanzaQueue == NULL)
			willReceiveStanzaQueue = dispatch_queue_create("xmpp.willReceiveStanza", DISPATCH_QUEUE_SERIAL);
		
		dispatch_async(willReceiveStanzaQueue, ^{ @autoreleasepool {
			
			// Allow delegates to modify and/or filter incoming element
			
			__block XMPPIQ *modifiedIQ = iq;
			
			id del;
			dispatch_queue_t dq;
			
			while (modifiedIQ && [delegateEnumerator getNextDelegate:&del delegateQueue:&dq forSelector:selector])
			{
				dispatch_sync(dq, ^{ @autoreleasepool {
					
					modifiedIQ = [del xmppStream:self willReceiveIQ:modifiedIQ];
					
				}});
			}
			
			dispatch_async(xmppQueue, ^{ @autoreleasepool {
				
				if (state == STATE_XMPP_CONNECTED)
				{
					if (modifiedIQ)
						[self continueReceiveIQ:modifiedIQ];
					else
						[multicastDelegate xmppStreamDidFilterStanza:self];
				}
			}});
		}});
	}
}

- (void)receiveMessage:(XMPPMessage *)message
{
	NSAssert(dispatch_get_specific(xmppQueueTag), @"Invoked on incorrect queue");
	NSAssert(state == STATE_XMPP_CONNECTED, @"Invoked with incorrect state");
	
	// We're getting ready to receive a message.
	// Notify delegates to allow them to optionally alter/filter the incoming message.
	
	SEL selector = @selector(xmppStream:willReceiveMessage:);
	
	if (![multicastDelegate hasDelegateThatRespondsToSelector:selector])
	{
		// None of the delegates implement the method.
		// Use a shortcut.
		
		if (willReceiveStanzaQueue)
		{
			// But still go through the stanzaQueue in order to guarantee in-order-delivery of all received stanzas.
			
			dispatch_async(willReceiveStanzaQueue, ^{
				dispatch_async(xmppQueue, ^{ @autoreleasepool {
					
					if (state == STATE_XMPP_CONNECTED) {
						[self continueReceiveMessage:message];
					}
				}});
			});
		}
		else
		{
			[self continueReceiveMessage:message];
		}
	}
	else
	{
		// Notify all interested delegates.
		// This must be done serially to allow them to alter the element in a thread-safe manner.
		
		GCDMulticastDelegateEnumerator *delegateEnumerator = [multicastDelegate delegateEnumerator];
		
		if (willReceiveStanzaQueue == NULL)
			willReceiveStanzaQueue = dispatch_queue_create("xmpp.willReceiveStanza", DISPATCH_QUEUE_SERIAL);
		
		dispatch_async(willReceiveStanzaQueue, ^{ @autoreleasepool {
			
			// Allow delegates to modify incoming element
			
			__block XMPPMessage *modifiedMessage = message;
			
			id del;
			dispatch_queue_t dq;
			
			while (modifiedMessage && [delegateEnumerator getNextDelegate:&del delegateQueue:&dq forSelector:selector])
			{
				dispatch_sync(dq, ^{ @autoreleasepool {
					
					modifiedMessage = [del xmppStream:self willReceiveMessage:modifiedMessage];
					
				}});
			}
			
			dispatch_async(xmppQueue, ^{ @autoreleasepool {
				
				if (state == STATE_XMPP_CONNECTED)
				{
					if (modifiedMessage)
						[self continueReceiveMessage:modifiedMessage];
					else
						[multicastDelegate xmppStreamDidFilterStanza:self];
				}
			}});
		}});
	}
}

- (void)receivePresence:(XMPPPresence *)presence
{
	NSAssert(dispatch_get_specific(xmppQueueTag), @"Invoked on incorrect queue");
	NSAssert(state == STATE_XMPP_CONNECTED, @"Invoked with incorrect state");
	
	// We're getting ready to receive a presence element.
	// Notify delegates to allow them to optionally alter/filter the incoming presence.
	
	SEL selector = @selector(xmppStream:willReceivePresence:);
	
	if (![multicastDelegate hasDelegateThatRespondsToSelector:selector])
	{
		// None of the delegates implement the method.
		// Use a shortcut.
		
		if (willReceiveStanzaQueue)
		{
			// But still go through the stanzaQueue in order to guarantee in-order-delivery of all received stanzas.
			
			dispatch_async(willReceiveStanzaQueue, ^{
				dispatch_async(xmppQueue, ^{ @autoreleasepool {
					
					if (state == STATE_XMPP_CONNECTED) {
						[self continueReceivePresence:presence];
					}
				}});
			});
		}
		else
		{
			[self continueReceivePresence:presence];
		}
	}
	else
	{
		// Notify all interested delegates.
		// This must be done serially to allow them to alter the element in a thread-safe manner.
		
		GCDMulticastDelegateEnumerator *delegateEnumerator = [multicastDelegate delegateEnumerator];
		
		if (willReceiveStanzaQueue == NULL)
			willReceiveStanzaQueue = dispatch_queue_create("xmpp.willReceiveStanza", DISPATCH_QUEUE_SERIAL);
		
		dispatch_async(willReceiveStanzaQueue, ^{ @autoreleasepool {
			
			// Allow delegates to modify outgoing element
			
			__block XMPPPresence *modifiedPresence = presence;
			
			id del;
			dispatch_queue_t dq;
			
			while (modifiedPresence && [delegateEnumerator getNextDelegate:&del delegateQueue:&dq forSelector:selector])
			{
				dispatch_sync(dq, ^{ @autoreleasepool {
					
					modifiedPresence = [del xmppStream:self willReceivePresence:modifiedPresence];
					
				}});
			}
			
			dispatch_async(xmppQueue, ^{ @autoreleasepool {
				
				if (state == STATE_XMPP_CONNECTED)
				{
					if (modifiedPresence)
						[self continueReceivePresence:presence];
					else
						[multicastDelegate xmppStreamDidFilterStanza:self];
				}
			}});
		}});
	}
}

- (void)continueReceiveIQ:(XMPPIQ *)iq
{
	if ([iq requiresResponse])
	{
		// As per the XMPP specificiation, if the IQ requires a response,
		// and we don't have any delegates or modules that can properly respond to the IQ,
		// we MUST send back and error IQ.
		//
		// So we notifiy all interested delegates and modules about the received IQ,
		// keeping track of whether or not any of them have handled it.
		
		GCDMulticastDelegateEnumerator *delegateEnumerator = [multicastDelegate delegateEnumerator];
		
		id del;
		dispatch_queue_t dq;
		
		SEL selector = @selector(xmppStream:didReceiveIQ:);
		
		dispatch_semaphore_t delSemaphore = dispatch_semaphore_create(0);
		dispatch_group_t delGroup = dispatch_group_create();
		
		while ([delegateEnumerator getNextDelegate:&del delegateQueue:&dq forSelector:selector])
		{
			dispatch_group_async(delGroup, dq, ^{ @autoreleasepool {
				
				if ([del xmppStream:self didReceiveIQ:iq])
				{
					dispatch_semaphore_signal(delSemaphore);
				}
				
			}});
		}
		
		dispatch_async(didReceiveIqQueue, ^{ @autoreleasepool {
			
			dispatch_group_wait(delGroup, DISPATCH_TIME_FOREVER);
			
			// Did any of the delegates handle the IQ? (handle == will response)
			
			BOOL handled = (dispatch_semaphore_wait(delSemaphore, DISPATCH_TIME_NOW) == 0);
			
			// An entity that receives an IQ request of type "get" or "set" MUST reply
			// with an IQ response of type "result" or "error".
			//
			// The response MUST preserve the 'id' attribute of the request.
			
			if (!handled)
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
				}
				
				// Purposefully go through the sendElement: method
				// so that it gets dispatched onto the xmppQueue,
				// and so that modules may get notified of the outgoing error message.
				
				[self sendElement:iqResponse];
			}
			
			#if !OS_OBJECT_USE_OBJC
			dispatch_release(delSemaphore);
			dispatch_release(delGroup);
			#endif
			
		}});
	}
	else
	{
		// The IQ doesn't require a response.
		// So we can just fire the delegate method and ignore the responses.
		
		[multicastDelegate xmppStream:self didReceiveIQ:iq];
	}
}

- (void)continueReceiveMessage:(XMPPMessage *)message
{
	[multicastDelegate xmppStream:self didReceiveMessage:message];
}

- (void)continueReceivePresence:(XMPPPresence *)presence
{
	[multicastDelegate xmppStream:self didReceivePresence:presence];
}

/**
 * This method allows you to inject an element into the stream as if it was received on the socket.
 * This is an advanced technique, but makes for some interesting possibilities.
**/
- (void)injectElement:(NSXMLElement *)element
{
	if (element == nil) return;
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		if (state != STATE_XMPP_CONNECTED)
		{
			return_from_block;
		}
		
		if ([element isKindOfClass:[XMPPIQ class]])
		{
			[self receiveIQ:(XMPPIQ *)element];
		}
		else if ([element isKindOfClass:[XMPPMessage class]])
		{
			[self receiveMessage:(XMPPMessage *)element];
		}
		else if ([element isKindOfClass:[XMPPPresence class]])
		{
			[self receivePresence:(XMPPPresence *)element];
		}
		else
		{
			NSString *elementName = [element name];
			
			if ([elementName isEqualToString:@"iq"])
			{
				[self receiveIQ:[XMPPIQ iqFromElement:element]];
			}
			else if ([elementName isEqualToString:@"message"])
			{
				[self receiveMessage:[XMPPMessage messageFromElement:element]];
			}
			else if ([elementName isEqualToString:@"presence"])
			{
				[self receivePresence:[XMPPPresence presenceFromElement:element]];
			}
			else if ([customElementNames countForObject:elementName])
			{
				[multicastDelegate xmppStream:self didReceiveCustomElement:element];
			}
			else
			{
				[multicastDelegate xmppStream:self didReceiveError:element];
			}
		}
	}};
	
	if (dispatch_get_specific(xmppQueueTag))
		block();
	else
		dispatch_async(xmppQueue, block);
}

- (void)registerCustomElementNames:(NSSet *)names
{
	dispatch_block_t block = ^{
		
		if (customElementNames == nil)
			customElementNames = [[NSCountedSet alloc] init];
		
		for (NSString *name in names)
		{
			[customElementNames addObject:name];
		}
	};
	
	if (dispatch_get_specific(xmppQueueTag))
		block();
	else
		dispatch_sync(xmppQueue, block);
}

- (void)unregisterCustomElementNames:(NSSet *)names
{
	dispatch_block_t block = ^{
		
		for (NSString *name in names)
		{
			[customElementNames removeObject:name];
		}
	};
	
	if (dispatch_get_specific(xmppQueueTag))
		block();
	else
		dispatch_sync(xmppQueue, block);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Stream Negotiation
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method is called to start the initial negotiation process.
**/
- (void)startNegotiation
{
	NSAssert(dispatch_get_specific(xmppQueueTag), @"Invoked on incorrect queue");
	NSAssert(![self didStartNegotiation], @"Invoked after initial negotiation has started");
	
	XMPPLogTrace();
	
	// Initialize the XML stream
	[self sendOpeningNegotiation];
	
	// Inform delegate that the TCP connection is open, and the stream handshake has begun
	[multicastDelegate xmppStreamDidStartNegotiation:self];
	
	// And start reading in the server's XML stream
	[asyncSocket readDataWithTimeout:TIMEOUT_XMPP_READ_START tag:TAG_XMPP_READ_START];
}

/**
 * This method handles sending the opening <stream:stream ...> element which is needed in several situations.
**/
- (void)sendOpeningNegotiation
{
	NSAssert(dispatch_get_specific(xmppQueueTag), @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	if (![self didStartNegotiation])
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
	
	if (parser == nil)
	{
		XMPPLogVerbose(@"%@: Initializing parser...", THIS_FILE);
		
		// Need to create the parser.
		parser = [[XMPPParser alloc] initWithDelegate:self delegateQueue:xmppQueue];
	}
	else
	{
		XMPPLogVerbose(@"%@: Resetting parser...", THIS_FILE);
		
		// We're restarting our negotiation, so we need to reset the parser.
		parser = [[XMPPParser alloc] initWithDelegate:self delegateQueue:xmppQueue];
	}
	
	NSString *xmlns = @"jabber:client";
	NSString *xmlns_stream = @"http://etherx.jabber.org/streams";
	
	NSString *temp, *s2;
    if ([self isP2P])
    {
		if (myJID_setByClient && remoteJID)
		{
			temp = @"<stream:stream xmlns='%@' xmlns:stream='%@' version='1.0' from='%@' to='%@'>";
			s2 = [NSString stringWithFormat:temp, xmlns, xmlns_stream, [myJID_setByClient bare], [remoteJID bare]];
		}
		else if (myJID_setByClient)
		{
			temp = @"<stream:stream xmlns='%@' xmlns:stream='%@' version='1.0' from='%@'>";
			s2 = [NSString stringWithFormat:temp, xmlns, xmlns_stream, [myJID_setByClient bare]];
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
		if (myJID_setByClient)
		{
			temp = @"<stream:stream xmlns='%@' xmlns:stream='%@' version='1.0' to='%@'>";
            s2 = [NSString stringWithFormat:temp, xmlns, xmlns_stream, [myJID_setByClient domain]];
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
	NSAssert(dispatch_get_specific(xmppQueueTag), @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	// Update state (part 2 - prompting delegates)
	state = STATE_XMPP_STARTTLS_2;
	
	// Create a mutable dictionary for security settings
	NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithCapacity:5];
	
	SEL selector = @selector(xmppStream:willSecureWithSettings:);
	
	if (![multicastDelegate hasDelegateThatRespondsToSelector:selector])
	{
		// None of the delegates implement the method.
		// Use a shortcut.
		
		[self continueStartTLS:settings];
	}
	else
	{
		// Query all interested delegates.
		// This must be done serially to maintain thread safety.
		
		GCDMulticastDelegateEnumerator *delegateEnumerator = [multicastDelegate delegateEnumerator];
		
		dispatch_queue_t concurrentQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
		dispatch_async(concurrentQueue, ^{ @autoreleasepool {
			
			// Prompt the delegate(s) to populate the security settings
			
			id delegate;
			dispatch_queue_t delegateQueue;
			
			while ([delegateEnumerator getNextDelegate:&delegate delegateQueue:&delegateQueue forSelector:selector])
			{
				dispatch_sync(delegateQueue, ^{ @autoreleasepool {
					
					[delegate xmppStream:self willSecureWithSettings:settings];
					
				}});
			}
			
			dispatch_async(xmppQueue, ^{ @autoreleasepool {
				
				[self continueStartTLS:settings];
				
			}});
			
		}});
	}
}

- (void)continueStartTLS:(NSMutableDictionary *)settings
{
	NSAssert(dispatch_get_specific(xmppQueueTag), @"Invoked on incorrect queue");
	
	XMPPLogTrace2(@"%@: %@ %@", THIS_FILE, THIS_METHOD, settings);
	
	if (state == STATE_XMPP_STARTTLS_2)
	{
		// If the delegates didn't respond
		if ([settings count] == 0)
		{
			// Use the default settings, and set the peer name
			
			NSString *expectedCertName = hostName;
			if (expectedCertName == nil)
			{
				expectedCertName = [myJID_setByClient domain];
			}
			
			if ([expectedCertName length] > 0)
			{
				settings[(NSString *) kCFStreamSSLPeerName] = expectedCertName;
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
			
			// We paused reading from the socket.
			// We're ready to continue now.
			[asyncSocket readDataWithTimeout:TIMEOUT_XMPP_READ_STREAM tag:TAG_XMPP_READ_STREAM];
		}
		else
		{
			// First time starting negotiation
			[self startNegotiation];
		}
	}
}

/**
 * This method is called anytime we receive the server's stream features.
 * This method looks at the stream features, and handles any requirements so communication can continue.
**/
- (void)handleStreamFeatures
{
	NSAssert(dispatch_get_specific(xmppQueueTag), @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	// Extract the stream features
	NSXMLElement *features = [rootElement elementForName:@"stream:features"];
	
	// Check to see if TLS is required
	// Don't forget about that NSXMLElement bug you reported to apple (xmlns is required or element won't be found)
	NSXMLElement *f_starttls = [features elementForName:@"starttls" xmlns:@"urn:ietf:params:xml:ns:xmpp-tls"];
	
	if (f_starttls)
	{
		if ([f_starttls elementForName:@"required"] || [self startTLSPolicy] >= XMPPStreamStartTLSPolicyPreferred)
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
    else if (![self isSecure] && [self startTLSPolicy] == XMPPStreamStartTLSPolicyRequired)
    {
		// We must abort the connection as the server doesn't support our requirements.
		
		NSString *errMsg = @"The server does not support startTLS. And the startTLSPolicy is Required.";
		NSDictionary *info = @{NSLocalizedDescriptionKey : errMsg};
		
		otherError = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamUnsupportedAction userInfo:info];
		
        // Close the TCP connection.
		[self disconnect];
		
		// The socketDidDisconnect:withError: method will handle everything else
		return;
    }
	
	// Check to see if resource binding is required
	// Don't forget about that NSXMLElement bug you reported to apple (xmlns is required or element won't be found)
	NSXMLElement *f_bind = [features elementForName:@"bind" xmlns:@"urn:ietf:params:xml:ns:xmpp-bind"];
	
	if (f_bind)
	{
		// Start the binding process
		[self startBinding];
		
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
	NSAssert(dispatch_get_specific(xmppQueueTag), @"Invoked on incorrect queue");
	
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
	NSAssert(dispatch_get_specific(xmppQueueTag), @"Invoked on incorrect queue");
	
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
 * After the authenticate:error: or authenticateWithPassword:error: methods are invoked, some kind of
 * authentication message is sent to the server.
 * This method forwards the response to the authentication module, and handles the resulting authentication state.
**/
- (void)handleAuth:(NSXMLElement *)authResponse
{
	NSAssert(dispatch_get_specific(xmppQueueTag), @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	XMPPHandleAuthResponse result = [auth handleAuth:authResponse];
	
	if (result == XMPP_AUTH_SUCCESS)
	{
		// We are successfully authenticated (via sasl:digest-md5)
		[self setIsAuthenticated:YES];
		
		BOOL shouldRenegotiate = YES;
		if ([auth respondsToSelector:@selector(shouldResendOpeningNegotiationAfterSuccessfulAuthentication)])
		{
			shouldRenegotiate = [auth shouldResendOpeningNegotiationAfterSuccessfulAuthentication];
		}
		
		if (shouldRenegotiate)
		{
			// Now we start our negotiation over again...
			[self sendOpeningNegotiation];
			
			if (![self isSecure])
			{
				// Normally we requeue our read operation in xmppParserDidParseData:.
				// But we just reset the parser, so that code path isn't going to happen.
				// So start read request here.
				// The state is STATE_XMPP_OPENING, set via sendOpeningNegotiation method.
				
				[asyncSocket readDataWithTimeout:TIMEOUT_XMPP_READ_START tag:TAG_XMPP_READ_START];
			}
		}
		else
		{
			// Revert back to connected state (from authenticating state)
			state = STATE_XMPP_CONNECTED;
			
			[multicastDelegate xmppStreamDidAuthenticate:self];
		}
		
		// Done with auth
		auth = nil;
		
	}
	else if (result == XMPP_AUTH_FAIL)
	{
		// Revert back to connected state (from authenticating state)
		state = STATE_XMPP_CONNECTED;
		
		// Notify delegate
		[multicastDelegate xmppStream:self didNotAuthenticate:authResponse];
		
		// Done with auth
		auth = nil;
		
	}
	else if (result == XMPP_AUTH_CONTINUE)
	{
		// Authentication continues.
		// State doesn't change.
	}
	else
	{
		XMPPLogError(@"Authentication class (%@) returned invalid response code (%i)",
		           NSStringFromClass([auth class]), (int)result);
		
		NSAssert(NO, @"Authentication class (%@) returned invalid response code (%i)",
		             NSStringFromClass([auth class]), (int)result);
	}
}

- (void)startBinding
{
	XMPPLogTrace();
	
	state = STATE_XMPP_BINDING;
	
	SEL selector = @selector(xmppStreamWillBind:);
	
	if (![multicastDelegate hasDelegateThatRespondsToSelector:selector])
	{
		[self startStandardBinding];
	}
	else
	{
		GCDMulticastDelegateEnumerator *delegateEnumerator = [multicastDelegate delegateEnumerator];
		
		dispatch_queue_t concurrentQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
		dispatch_async(concurrentQueue, ^{ @autoreleasepool {
			
			__block id <XMPPCustomBinding> delegateCustomBinding = nil;
			
			id delegate;
			dispatch_queue_t dq;
			
			while ([delegateEnumerator getNextDelegate:&delegate delegateQueue:&dq forSelector:selector])
			{
				dispatch_sync(dq, ^{ @autoreleasepool {
					
					delegateCustomBinding = [delegate xmppStreamWillBind:self];
				}});
				
				if (delegateCustomBinding) {
					break;
				}
			}
			
			dispatch_async(xmppQueue, ^{ @autoreleasepool {
				
				if (delegateCustomBinding)
					[self startCustomBinding:delegateCustomBinding];
				else
					[self startStandardBinding];
			}});
		}});
	}
}

- (void)startCustomBinding:(id <XMPPCustomBinding>)delegateCustomBinding
{
	XMPPLogTrace();
	
	customBinding = delegateCustomBinding;
	
	NSError *bindError = nil;
	XMPPBindResult result = [customBinding start:&bindError];
	
	if (result == XMPP_BIND_CONTINUE)
	{
		// Expected result
		// Wait for reply from server, and forward to customBinding module.
	}
	else
	{
		if (result == XMPP_BIND_SUCCESS)
		{
			// It appears binding isn't needed (perhaps handled via auth)
			
			BOOL skipStartSessionOverride = NO;
			if ([customBinding respondsToSelector:@selector(shouldSkipStartSessionAfterSuccessfulBinding)]) {
				skipStartSessionOverride = [customBinding shouldSkipStartSessionAfterSuccessfulBinding];
			}
			
			[self continuePostBinding:skipStartSessionOverride];
		}
		else if (result == XMPP_BIND_FAIL_FALLBACK)
		{
			// Custom binding isn't available for whatever reason,
			// but the module has requested we fallback to standard binding.
			
			[self startStandardBinding];
		}
		else if (result == XMPP_BIND_FAIL_ABORT)
		{
			// Custom binding failed,
			// and the module requested we abort.
			
			otherError = bindError;
			[asyncSocket disconnect];
		}
		
		customBinding = nil;
	}
}

- (void)handleCustomBinding:(NSXMLElement *)response
{
	XMPPLogTrace();
	
	NSError *bindError = nil;
	XMPPBindResult result = [customBinding handleBind:response withError:&bindError];
	
	if (result == XMPP_BIND_CONTINUE)
	{
		// Binding still in progress
	}
	else
	{
		if (result == XMPP_BIND_SUCCESS)
		{
			// Binding complete. Continue.
			
			BOOL skipStartSessionOverride = NO;
			if ([customBinding respondsToSelector:@selector(shouldSkipStartSessionAfterSuccessfulBinding)]) {
				skipStartSessionOverride = [customBinding shouldSkipStartSessionAfterSuccessfulBinding];
			}
			
			[self continuePostBinding:skipStartSessionOverride];
		}
		else if (result == XMPP_BIND_FAIL_FALLBACK)
		{
			// Custom binding failed for whatever reason,
			// but the module has requested we fallback to standard binding.
			
			[self startStandardBinding];
		}
		else if (result == XMPP_BIND_FAIL_ABORT)
		{
			// Custom binding failed,
			// and the module requested we abort.
			
			otherError = bindError;
			[asyncSocket disconnect];
		}
		
		customBinding = nil;
	}
}

- (void)startStandardBinding
{
	XMPPLogTrace();
	
	NSString *requestedResource = [myJID_setByClient resource];
	
	if ([requestedResource length] > 0)
	{
		// Ask the server to bind the user specified resource
		
		NSXMLElement *resource = [NSXMLElement elementWithName:@"resource"];
		[resource setStringValue:requestedResource];
		
		NSXMLElement *bind = [NSXMLElement elementWithName:@"bind" xmlns:@"urn:ietf:params:xml:ns:xmpp-bind"];
		[bind addChild:resource];
		
		XMPPIQ *iq = [XMPPIQ iqWithType:@"set" elementID:[self generateUUID]];
		[iq addChild:bind];
		
		NSString *outgoingStr = [iq compactXMLString];
		NSData *outgoingData = [outgoingStr dataUsingEncoding:NSUTF8StringEncoding];
		
		XMPPLogSend(@"SEND: %@", outgoingStr);
		numberOfBytesSent += [outgoingData length];
		
		[asyncSocket writeData:outgoingData
				   withTimeout:TIMEOUT_XMPP_WRITE
						   tag:TAG_XMPP_WRITE_STREAM];
        
		[idTracker addElement:iq
		               target:nil
		             selector:NULL
		              timeout:XMPPIDTrackerTimeoutNone];
	}
	else
	{
		// The user didn't specify a resource, so we ask the server to bind one for us
		
		NSXMLElement *bind = [NSXMLElement elementWithName:@"bind" xmlns:@"urn:ietf:params:xml:ns:xmpp-bind"];
		
		XMPPIQ *iq = [XMPPIQ iqWithType:@"set" elementID:[self generateUUID]];
		[iq addChild:bind];
		
		NSString *outgoingStr = [iq compactXMLString];
		NSData *outgoingData = [outgoingStr dataUsingEncoding:NSUTF8StringEncoding];
		
		XMPPLogSend(@"SEND: %@", outgoingStr);
		numberOfBytesSent += [outgoingData length];
		
		[asyncSocket writeData:outgoingData
				   withTimeout:TIMEOUT_XMPP_WRITE
						   tag:TAG_XMPP_WRITE_STREAM];
        
		[idTracker addElement:iq
		               target:nil
		             selector:NULL
		              timeout:XMPPIDTrackerTimeoutNone];
	}
}

- (void)handleStandardBinding:(NSXMLElement *)response
{
	NSAssert(dispatch_get_specific(xmppQueueTag), @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	NSXMLElement *r_bind = [response elementForName:@"bind" xmlns:@"urn:ietf:params:xml:ns:xmpp-bind"];
	NSXMLElement *r_jid = [r_bind elementForName:@"jid"];
	
	if (r_jid)
	{
		// We're properly binded to a resource now
		// Extract and save our resource (it may not be what we originally requested)
		NSString *fullJIDStr = [r_jid stringValue];
		
		[self setMyJID_setByServer:[XMPPJID jidWithString:fullJIDStr]];
		
		// On to the next step
		BOOL skipStartSessionOverride = NO;
		[self continuePostBinding:skipStartSessionOverride];
	}
	else
	{
		// It appears the server didn't allow our resource choice
		// First check if we want to try an alternative resource
		
		NSXMLElement *r_error = [response elementForName:@"error"];
		NSXMLElement *r_conflict = [r_error elementForName:@"conflict" xmlns:@"urn:ietf:params:xml:ns:xmpp-stanzas"];
        
		if (r_conflict)
		{
			SEL selector = @selector(xmppStream:alternativeResourceForConflictingResource:);
			
			if (![multicastDelegate hasDelegateThatRespondsToSelector:selector])
			{
				// None of the delegates implement the method.
				// Use a shortcut.
				
				[self continueHandleStandardBinding:nil];
			}
			else
			{
				// Query all interested delegates.
				// This must be done serially to maintain thread safety.
				
				GCDMulticastDelegateEnumerator *delegateEnumerator = [multicastDelegate delegateEnumerator];
				
				dispatch_queue_t concurrentQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
				dispatch_async(concurrentQueue, ^{ @autoreleasepool {
					
					// Query delegates for alternative resource
					
					NSString *currentResource = [[self myJID] resource];
					__block NSString *alternativeResource = nil;
					
					id delegate;
					dispatch_queue_t dq;
					
					while ([delegateEnumerator getNextDelegate:&delegate delegateQueue:&dq forSelector:selector])
					{
						dispatch_sync(dq, ^{ @autoreleasepool {
							
							NSString *delegateAlternativeResource =
							    [delegate xmppStream:self alternativeResourceForConflictingResource:currentResource];
							
							if (delegateAlternativeResource)
							{
								alternativeResource = delegateAlternativeResource;
							}
						}});
						
						if (alternativeResource) {
							break;
						}
					}
					
					dispatch_async(xmppQueue, ^{ @autoreleasepool {
						
						[self continueHandleStandardBinding:alternativeResource];
						
					}});
					
				}});
			}
        }
		else
		{
			// Appears to be a conflicting resource, but server didn't specify conflict
			[self continueHandleStandardBinding:nil];
		}
	}
}

- (void)continueHandleStandardBinding:(NSString *)alternativeResource
{
	XMPPLogTrace();
	
	if ([alternativeResource length] > 0)
	{
		// Update myJID
		
		[self setMyJID_setByClient:[myJID_setByClient jidWithNewResource:alternativeResource]];
		
		NSXMLElement *resource = [NSXMLElement elementWithName:@"resource"];
		[resource setStringValue:alternativeResource];
		
		NSXMLElement *bind = [NSXMLElement elementWithName:@"bind" xmlns:@"urn:ietf:params:xml:ns:xmpp-bind"];
		[bind addChild:resource];
		
		XMPPIQ *iq = [XMPPIQ iqWithType:@"set"];
		[iq addChild:bind];
		
		NSString *outgoingStr = [iq compactXMLString];
		NSData *outgoingData = [outgoingStr dataUsingEncoding:NSUTF8StringEncoding];
		
		XMPPLogSend(@"SEND: %@", outgoingStr);
		numberOfBytesSent += [outgoingData length];
		
		[asyncSocket writeData:outgoingData
		           withTimeout:TIMEOUT_XMPP_WRITE
		                   tag:TAG_XMPP_WRITE_STREAM];
        
        [idTracker addElement:iq
                       target:nil
                     selector:NULL
                      timeout:XMPPIDTrackerTimeoutNone];
		
		// The state remains in STATE_XMPP_BINDING
	}
	else
	{
		// We'll simply let the server choose then
		
		NSXMLElement *bind = [NSXMLElement elementWithName:@"bind" xmlns:@"urn:ietf:params:xml:ns:xmpp-bind"];
		
		XMPPIQ *iq = [XMPPIQ iqWithType:@"set"];
		[iq addChild:bind];
		
		NSString *outgoingStr = [iq compactXMLString];
		NSData *outgoingData = [outgoingStr dataUsingEncoding:NSUTF8StringEncoding];
		
		XMPPLogSend(@"SEND: %@", outgoingStr);
		numberOfBytesSent += [outgoingData length];
		
		[asyncSocket writeData:outgoingData
		           withTimeout:TIMEOUT_XMPP_WRITE
		                   tag:TAG_XMPP_WRITE_STREAM];
        
        [idTracker addElement:iq
                       target:nil
                     selector:NULL
                      timeout:XMPPIDTrackerTimeoutNone];
		
		// The state remains in STATE_XMPP_BINDING
	}
}

- (void)continuePostBinding:(BOOL)skipStartSessionOverride
{
	XMPPLogTrace();
	
	// And we may now have to do one last thing before we're ready - start an IM session
	NSXMLElement *features = [rootElement elementForName:@"stream:features"];
	
	// Check to see if a session is required
	// Don't forget about that NSXMLElement bug you reported to apple (xmlns is required or element won't be found)
	NSXMLElement *f_session = [features elementForName:@"session" xmlns:@"urn:ietf:params:xml:ns:xmpp-session"];
	
	if (f_session && !skipStartSession && !skipStartSessionOverride)
	{
		NSXMLElement *session = [NSXMLElement elementWithName:@"session"];
		[session setXmlns:@"urn:ietf:params:xml:ns:xmpp-session"];
		
		XMPPIQ *iq = [XMPPIQ iqWithType:@"set" elementID:[self generateUUID]];
		[iq addChild:session];
		
		NSString *outgoingStr = [iq compactXMLString];
		NSData *outgoingData = [outgoingStr dataUsingEncoding:NSUTF8StringEncoding];
		
		XMPPLogSend(@"SEND: %@", outgoingStr);
		numberOfBytesSent += [outgoingData length];
		
		[asyncSocket writeData:outgoingData
				   withTimeout:TIMEOUT_XMPP_WRITE
						   tag:TAG_XMPP_WRITE_STREAM];
        
		[idTracker addElement:iq
		               target:nil
		             selector:NULL
		              timeout:XMPPIDTrackerTimeoutNone];
		
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

- (void)handleStartSessionResponse:(NSXMLElement *)response
{
	NSAssert(dispatch_get_specific(xmppQueueTag), @"Invoked on incorrect queue");
	
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
	NSAssert(dispatch_get_specific(xmppQueueTag), @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	NSError *connectError = nil;
	BOOL success = NO;
	
	while (srvResultsIndex < [srvResults count])
	{
		XMPPSRVRecord *srvRecord = srvResults[srvResultsIndex];
		NSString *srvHost = srvRecord.target;
		UInt16 srvPort    = srvRecord.port;
		
		success = [self connectToHost:srvHost onPort:srvPort withTimeout:XMPPStreamTimeoutNone error:&connectError];
		
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
		
		success = [self connectToHost:[myJID_setByClient domain] onPort:5222 withTimeout:XMPPStreamTimeoutNone error:&connectError];
	}
	
	if (!success)
	{
		[self endConnectTimeout];
		
		state = STATE_XMPP_DISCONNECTED;
		
		[multicastDelegate xmppStreamDidDisconnect:self withError:connectError];
	}
}

- (void)xmppSRVResolver:(XMPPSRVResolver *)sender didResolveRecords:(NSArray *)records
{
	NSAssert(dispatch_get_specific(xmppQueueTag), @"Invoked on incorrect queue");
	
	if (sender != srvResolver) return;
	
	XMPPLogTrace();
	
	srvResults = [records copy];
	srvResultsIndex = 0;
	
	state = STATE_XMPP_CONNECTING;
	
	[self tryNextSrvResult];
}

- (void)xmppSRVResolver:(XMPPSRVResolver *)sender didNotResolveDueToError:(NSError *)error
{
	NSAssert(dispatch_get_specific(xmppQueueTag), @"Invoked on incorrect queue");
	
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
    
    [self endConnectTimeout];
	
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
	
	srvResolver = nil;
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

- (void)socket:(GCDAsyncSocket *)sock didReceiveTrust:(SecTrustRef)trust
                                    completionHandler:(void (^)(BOOL shouldTrustPeer))completionHandler
{
	XMPPLogTrace();
	
	SEL selector = @selector(xmppStream:didReceiveTrust:completionHandler:);
	
	if ([multicastDelegate hasDelegateThatRespondsToSelector:selector])
	{
		[multicastDelegate xmppStream:self didReceiveTrust:trust completionHandler:completionHandler];
	}
	else
	{
		XMPPLogWarn(@"%@: Stream secured with (GCDAsyncSocketManuallyEvaluateTrust == YES),"
		            @" but there are no delegates that implement xmppStream:didReceiveTrust:completionHandler:."
		            @" This is likely a mistake.", THIS_FILE);
		
		// The delegate method should likely have code similar to this,
		// but will presumably perform some extra security code stuff.
		// For example, allowing a specific self-signed certificate that is known to the app.
		
		dispatch_queue_t bgQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
		dispatch_async(bgQueue, ^{
			
			SecTrustResultType result = kSecTrustResultDeny;
			OSStatus status = SecTrustEvaluate(trust, &result);
			
			if (status == noErr && (result == kSecTrustResultProceed || result == kSecTrustResultUnspecified)) {
				completionHandler(YES);
			}
			else {
				completionHandler(NO);
			}
		});
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
	numberOfBytesReceived += [data length];
	
	XMPPLogRecvPre(@"RECV: %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
	
	// Asynchronously parse the xml data
	[parser parseData:data];
	
	if ([self isSecure])
	{
		// Continue reading for XML elements
		if (state == STATE_XMPP_OPENING)
		{
			[asyncSocket readDataWithTimeout:TIMEOUT_XMPP_READ_START tag:TAG_XMPP_READ_START];
		}
		else
		{
			[asyncSocket readDataWithTimeout:TIMEOUT_XMPP_READ_STREAM tag:TAG_XMPP_READ_STREAM];
		}
	}
	else
	{
		// Don't queue up a read on the socket as we may need to upgrade to TLS.
		// We'll read more data after we've parsed the current chunk of data.
	}
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
		
		XMPPElementReceipt *receipt = receipts[0];
		[receipt signalSuccess];
		[receipts removeObjectAtIndex:0];
	}
	else if (tag == TAG_XMPP_WRITE_STOP)
	{
		[multicastDelegate xmppStreamDidSendClosingStreamStanza:self];
	}
}

/**
 * Called when a socket disconnects with or without error.
**/
- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
	// This method is invoked on the xmppQueue.
	
	XMPPLogTrace();
    
    [self endConnectTimeout];
	
	if (srvResults && (++srvResultsIndex < [srvResults count]))
	{
		[self tryNextSrvResult];
	}
	else
	{
		// Update state
		state = STATE_XMPP_DISCONNECTED;
		
		// Release the parser (to free underlying resources)
		[parser setDelegate:nil delegateQueue:NULL];
		parser = nil;
		
		// Clear any saved authentication information
		auth = nil;
		
		authenticationDate = nil;
		
		// Clear stored elements
		myJID_setByServer = nil;
		myPresence = nil;
		rootElement = nil;
		
		// Stop the keep alive timer
		if (keepAliveTimer)
		{
			dispatch_source_cancel(keepAliveTimer);
			keepAliveTimer = NULL;
		}
		
		// Clear srv results
		srvResolver = nil;
		srvResults = nil;
        
        // Stop tracking IDs
        [idTracker removeAllIDs];
		
		// Clear any pending receipts
		for (XMPPElementReceipt *receipt in receipts)
		{
			[receipt signalFailure];
		}
		[receipts removeAllObjects];
		
		// Clear flags
		flags = 0;
		
		// Notify delegate
		
		if (parserError || otherError)
		{
			NSError *error = parserError ? : otherError;
			
			[multicastDelegate xmppStreamDidDisconnect:self withError:error];
			
			parserError = nil;
			otherError = nil;
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
	// This method is invoked on the xmppQueue.
	
	if (sender != parser) return;
	
	XMPPLogTrace();
	XMPPLogRecvPost(@"RECV: %@", [root compactXMLString]);
		
	// At this point we've sent our XML stream header, and we've received the response XML stream header.
	// We save the root element of our stream for future reference.
	
	rootElement = root;
	
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
			remoteJID = [XMPPJID jidWithString:from];
			
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
			
            XMPPIQ *iq = [XMPPIQ iqWithType:@"get" elementID:[self generateUUID]];
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
}

- (void)xmppParser:(XMPPParser *)sender didReadElement:(NSXMLElement *)element
{
	// This method is invoked on the xmppQueue.
	
	if (sender != parser) return;
	
	XMPPLogTrace();
	XMPPLogRecvPost(@"RECV: %@", [element compactXMLString]);
		
	NSString *elementName = [element name];
	
	if ([elementName isEqualToString:@"stream:error"] || [elementName isEqualToString:@"error"])
	{
		[multicastDelegate xmppStream:self didReceiveError:element];
		
		return;
	}
	
	if (state == STATE_XMPP_NEGOTIATING)
	{
		// We've just read in the stream features
		// We consider this part of the root element, so we'll add it (replacing any previously sent features)
    [rootElement setChildren:@[element]];
		
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
	else if (state == STATE_XMPP_AUTH)
	{
		// Some response to the authentication process
		[self handleAuth:element];
	}
	else if (state == STATE_XMPP_BINDING)
	{
		if (customBinding)
		{
			[self handleCustomBinding:element];
		}
		else
		{
			BOOL invalid = NO;
			if (validatesResponses)
			{
				XMPPIQ *iq = [XMPPIQ iqFromElement:element];
				if (![idTracker invokeForElement:iq withObject:nil])
				{
					invalid = YES;
				}
			}
			if (!invalid)
			{
				// The response from our binding request
				[self handleStandardBinding:element];
			}
		}
	}
	else if (state == STATE_XMPP_START_SESSION)
	{
		BOOL invalid = NO;
		if (validatesResponses)
		{
			XMPPIQ *iq = [XMPPIQ iqFromElement:element];
			if (![idTracker invokeForElement:iq withObject:nil])
			{
				invalid = YES;
			}
		}
		if (!invalid)
		{
			// The response from our start session request
			[self handleStartSessionResponse:element];
		}
	}
	else
	{
		if ([elementName isEqualToString:@"iq"])
		{
			[self receiveIQ:[XMPPIQ iqFromElement:element]];
		}
		else if ([elementName isEqualToString:@"message"])
		{
			[self receiveMessage:[XMPPMessage messageFromElement:element]];
		}
		else if ([elementName isEqualToString:@"presence"])
		{
			[self receivePresence:[XMPPPresence presenceFromElement:element]];
		}
		else if ([self isP2P] &&
		        ([elementName isEqualToString:@"stream:features"] || [elementName isEqualToString:@"features"]))
		{
			[multicastDelegate xmppStream:self didReceiveP2PFeatures:element];
		}
		else if ([customElementNames countForObject:elementName])
		{
			[multicastDelegate xmppStream:self didReceiveCustomElement:element];
		}
		else
		{
			[multicastDelegate xmppStream:self didReceiveError:element];
		}
	}
}

- (void)xmppParserDidParseData:(XMPPParser *)sender
{
	// This method is invoked on the xmppQueue.
	
	if (sender != parser) return;
	
	XMPPLogTrace();
	
	if (![self isSecure])
	{
		// Continue reading for XML elements
		if (state == STATE_XMPP_OPENING)
		{
			[asyncSocket readDataWithTimeout:TIMEOUT_XMPP_READ_START tag:TAG_XMPP_READ_START];
		}
		else if (state != STATE_XMPP_STARTTLS_2) // Don't queue read operation prior to [asyncSocket startTLS:]
		{
			[asyncSocket readDataWithTimeout:TIMEOUT_XMPP_READ_STREAM tag:TAG_XMPP_READ_STREAM];
		}
	}
}

- (void)xmppParserDidEnd:(XMPPParser *)sender
{
	// This method is invoked on the xmppQueue.
	
	if (sender != parser) return;
	
	XMPPLogTrace();
	
	[asyncSocket disconnect];
}

- (void)xmppParser:(XMPPParser *)sender didFail:(NSError *)error
{
	// This method is invoked on the xmppQueue.
	
	if (sender != parser) return;
	
	XMPPLogTrace();
	
	parserError = error;
	[asyncSocket disconnect];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Keep Alive
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)setupKeepAliveTimer
{
	NSAssert(dispatch_get_specific(xmppQueueTag), @"Invoked on incorrect queue");
	
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
			
			dispatch_source_set_event_handler(keepAliveTimer, ^{ @autoreleasepool {
				
				[self keepAlive];
			}});
			
			#if !OS_OBJECT_USE_OBJC
			dispatch_source_t theKeepAliveTimer = keepAliveTimer;
			
			dispatch_source_set_cancel_handler(keepAliveTimer, ^{
				XMPPLogVerbose(@"dispatch_release(keepAliveTimer)");
				dispatch_release(theKeepAliveTimer);
			});
			#endif
			
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
	NSAssert(dispatch_get_specific(xmppQueueTag), @"Invoked on incorrect queue");
	
	if (state == STATE_XMPP_CONNECTED)
	{
		NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
		NSTimeInterval elapsed = (now - lastSendReceiveTime);
		
		if (elapsed < 0 || elapsed >= keepAliveInterval)
		{
			numberOfBytesSent += [keepAliveData length];
			
			[asyncSocket writeData:keepAliveData
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
#pragma mark Stanza Validation
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)isValidResponseElementFrom:(XMPPJID *)from forRequestElementTo:(XMPPJID *)to
{
    BOOL valid = YES;
    
    if(to)
    {
        if(![to isEqualToJID:from])
        {
            valid = NO;
        }
    }
/**
 * Replies for Stanza's that had no TO will be accepted if the FROM is:
 *
 * No from.
 * from = the bare account JID.
 * from = the full account JID (legal in 3920, but not 6120).
 * from = the server's domain.
**/
    else if(!to && from)
    {
        if(![from isEqualToJID:self.myJID options:XMPPJIDCompareBare]
           && ![from isEqualToJID:self.myJID options:XMPPJIDCompareFull]
           && ![from isEqualToJID:[self.myJID domainJID] options:XMPPJIDCompareFull])
        {
            valid = NO;
        }
    }
    
    return valid;
}

- (BOOL)isValidResponseElement:(XMPPElement *)response forRequestElement:(XMPPElement *)request
{
    if(!response || !request) return NO;
    
    return [self isValidResponseElementFrom:[response from] forRequestElementTo:[request to]];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Module Plug-In System
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)registerModule:(XMPPModule *)module
{
	if (module == nil) return;
	
	// Asynchronous operation
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		// Register module
		
		[registeredModules addObject:module];
		
		// Add auto delegates (if there are any)
		
		NSString *className = NSStringFromClass([module class]);
		GCDMulticastDelegate *autoDelegates = autoDelegateDict[className];
		
		GCDMulticastDelegateEnumerator *autoDelegatesEnumerator = [autoDelegates delegateEnumerator];
		id delegate;
		dispatch_queue_t delegateQueue;
		
		while ([autoDelegatesEnumerator getNextDelegate:&delegate delegateQueue:&delegateQueue])
		{
			[module addDelegate:delegate delegateQueue:delegateQueue];
		}
		
		// Notify our own delegate(s)
		
		[multicastDelegate xmppStream:self didRegisterModule:module];
		
	}};
	
	// Asynchronous operation
	
	if (dispatch_get_specific(xmppQueueTag))
		block();
	else
		dispatch_async(xmppQueue, block);
}

- (void)unregisterModule:(XMPPModule *)module
{
	if (module == nil) return;
	
	// Synchronous operation
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		// Notify our own delegate(s)
		
		[multicastDelegate xmppStream:self willUnregisterModule:module];
		
		// Remove auto delegates (if there are any)
		
		NSString *className = NSStringFromClass([module class]);
		GCDMulticastDelegate *autoDelegates = autoDelegateDict[className];
		
		GCDMulticastDelegateEnumerator *autoDelegatesEnumerator = [autoDelegates delegateEnumerator];
		id delegate;
		dispatch_queue_t delegateQueue;
		
		while ([autoDelegatesEnumerator getNextDelegate:&delegate delegateQueue:&delegateQueue])
		{
			// The module itself has dispatch_sync'd in order to invoke its deactivate method,
			// which has in turn invoked this method. If we call back into the module,
			// and have it dispatch_sync again, we're going to get a deadlock.
			// So we must remove the delegate(s) asynchronously.
			
			[module removeDelegate:delegate delegateQueue:delegateQueue synchronously:NO];
		}
		
		// Unregister modules
		
		[registeredModules removeObject:module];
		
	}};
	
	// Synchronous operation
	
	if (dispatch_get_specific(xmppQueueTag))
		block();
	else
		dispatch_sync(xmppQueue, block);
}

- (void)autoAddDelegate:(id)delegate delegateQueue:(dispatch_queue_t)delegateQueue toModulesOfClass:(Class)aClass
{
	if (delegate == nil) return;
	if (aClass == nil) return;
	
	// Asynchronous operation
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		NSString *className = NSStringFromClass(aClass);
		
		// Add the delegate to all currently registered modules of the given class.
		
		for (XMPPModule *module in registeredModules)
		{
			if ([module isKindOfClass:aClass])
			{
				[module addDelegate:delegate delegateQueue:delegateQueue];
			}
		}
		
		// Add the delegate to list of auto delegates for the given class.
		// It will be added as a delegate to future registered modules of the given class.
		
		id delegates = autoDelegateDict[className];
		if (delegates == nil)
		{
			delegates = [[GCDMulticastDelegate alloc] init];
			
			autoDelegateDict[className] = delegates;
		}
		
		[delegates addDelegate:delegate delegateQueue:delegateQueue];
		
	}};
	
	// Asynchronous operation
	
	if (dispatch_get_specific(xmppQueueTag))
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
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		if (aClass == NULL)
		{
			// Remove the delegate from all currently registered modules of ANY class.
			
			for (XMPPModule *module in registeredModules)
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
			
			for (XMPPModule *module in registeredModules)
			{
				if ([module isKindOfClass:aClass])
				{
					[module removeDelegate:delegate delegateQueue:delegateQueue];
				}
			}
			
			// Remove the delegate from list of auto delegates for the given class,
			// so that it will not be added as a delegate to future registered modules of the given class.
			
			GCDMulticastDelegate *delegates = autoDelegateDict[className];
			[delegates removeDelegate:delegate delegateQueue:delegateQueue];
			
			if ([delegates count] == 0)
			{
				[autoDelegateDict removeObjectForKey:className];
			}
		}
		
	}};
	
	// Synchronous operation
	
	if (dispatch_get_specific(xmppQueueTag))
		block();
	else
		dispatch_sync(xmppQueue, block);
}

- (void)enumerateModulesWithBlock:(void (^)(XMPPModule *module, NSUInteger idx, BOOL *stop))enumBlock
{
	if (enumBlock == NULL) return;
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		NSUInteger i = 0;
		BOOL stop = NO;
		
		for (XMPPModule *module in registeredModules)
		{
			enumBlock(module, i, &stop);
			
			if (stop)
				break;
			else
				i++;
		}
	}};
	
	// Synchronous operation
	
	if (dispatch_get_specific(xmppQueueTag))
		block();
	else
		dispatch_sync(xmppQueue, block);
}

- (void)enumerateModulesOfClass:(Class)aClass withBlock:(void (^)(XMPPModule *module, NSUInteger idx, BOOL *stop))block
{
    [self enumerateModulesWithBlock:^(XMPPModule *module, NSUInteger idx, BOOL *stop)
    {
        if([module isKindOfClass:aClass])
        {
            block(module,idx,stop);
        }
    }];
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
		result = (__bridge_transfer NSString *)CFUUIDCreateString(NULL, uuid);
		CFRelease(uuid);
	}
	
	return result;
}

- (NSString *)generateUUID
{
	return [[self class] generateUUID];
}

/** Allocates and configures a new socket */
- (GCDAsyncSocket*) newSocket {
    GCDAsyncSocket *socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:xmppQueue];
    socket.IPv4PreferredOverIPv6 = !self.preferIPv6;
    return socket;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPElementReceipt

static const uint32_t receipt_unknown = 0 << 0;
static const uint32_t receipt_failure = 1 << 0;
static const uint32_t receipt_success = 1 << 1;


- (id)init
{
	if ((self = [super init]))
	{
		atomicFlags = receipt_unknown;
		semaphore = dispatch_semaphore_create(0);
	}
	return self;
}

- (void)signalSuccess
{
	uint32_t mask = receipt_success;
	OSAtomicOr32Barrier(mask, &atomicFlags);
	
	dispatch_semaphore_signal(semaphore);
}

- (void)signalFailure
{
	uint32_t mask = receipt_failure;
	OSAtomicOr32Barrier(mask, &atomicFlags);
	
	dispatch_semaphore_signal(semaphore);
}

- (BOOL)wait:(NSTimeInterval)timeout_seconds
{
	uint32_t mask = 0;
	uint32_t flags = OSAtomicOr32Barrier(mask, &atomicFlags);
	
	if (flags != receipt_unknown) return (flags == receipt_success);
	
	dispatch_time_t timeout_nanos;
	
	if (isless(timeout_seconds, 0.0))
		timeout_nanos = DISPATCH_TIME_FOREVER;
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
		
		return (flags == receipt_success);
	}
	else
	{
		// Timed out waiting...
		return NO;
	}
}

- (void)dealloc
{
	#if !OS_OBJECT_USE_OBJC
	dispatch_release(semaphore);
	#endif
}

@end
