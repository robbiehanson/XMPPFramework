// Define the timeouts (in seconds) for retreiving various parts of the XML stream
#define TIMEOUT_XMPP_WRITE         -1
#define TIMEOUT_XMPP_READ_START    10
#define TIMEOUT_XMPP_READ_STREAM   -1

// Define the tags we'll use to differentiate what it is we're currently reading or writing
#define TAG_XMPP_READ_START         100
#define TAG_XMPP_READ_STREAM        101
#define TAG_XMPP_WRITE_START        200
#define TAG_XMPP_WRITE_STREAM       201
#define TAG_XMPP_WRITE_RECEIPT      202

// Define the timeouts (in seconds) for SRV
#define TIMEOUT_SRV_RESOLUTION 30.0

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
	
	dispatch_queue_t willReceiveIqQueue;
	dispatch_queue_t willReceiveMessageQueue;
	dispatch_queue_t willReceivePresenceQueue;
	
	dispatch_queue_t didReceiveIqQueue;
    
	dispatch_source_t connectTimer;
	
	GCDMulticastDelegate <XMPPStreamDelegate> *multicastDelegate;
	
	int state;
	
	GCDAsyncSocket *asyncSocket;
	
	UInt64 numberOfBytesSent;
	UInt64 numberOfBytesReceived;
	
	XMPPParser *parser;
	NSError *parserError;
	
	Byte flags;
	Byte config;
	
	NSString *hostName;
	UInt16 hostPort;
    
	BOOL autoStartTLS;
	
	id <XMPPSASLAuthentication> auth;
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
	
	NSMutableArray *receipts;
	
	NSThread *xmppUtilityThread;
	NSRunLoop *xmppUtilityRunLoop;
	
	id userTag;
    
    NSMutableArray * registeredFeatures;
    NSMutableArray * registeredStreamPreprocessors;
    NSMutableArray * registeredElementHandlers;
    
}

- (void)setIsSecure:(BOOL)flag;
- (void)setIsAuthenticated:(BOOL)flag;
- (void)continueSendIQ:(XMPPIQ *)iq withTag:(long)tag;
- (void)continueSendMessage:(XMPPMessage *)message withTag:(long)tag;
- (void)continueSendPresence:(XMPPPresence *)presence withTag:(long)tag;
- (void)startNegotiation;
- (void)sendOpeningNegotiation;
- (void)continueStartTLS:(NSMutableDictionary *)settings;
- (void)continueHandleBinding:(NSString *)alternativeResource;
- (void)setupKeepAliveTimer;
- (void)keepAlive;

- (void)startConnectTimeout:(NSTimeInterval)timeout;
- (void)endConnectTimeout;
- (void)doConnectTimeout;

- (void)continueReceiveMessage:(XMPPMessage *)message;
- (void)continueReceiveIQ:(XMPPIQ *)iq;
- (void)continueReceivePresence:(XMPPPresence *)presence;

// A Wrapper, prepared for stream compression
- (void)writeData:(NSData *)data withTimeout:(NSTimeInterval)timeout tag:(long)tag;
- (void)readDataWithTimeout:(NSTimeInterval)timeout tag:(long)tag;
@end

@interface XMPPElementReceipt (PrivateAPI)

- (void)signalSuccess;
- (void)signalFailure;

@end