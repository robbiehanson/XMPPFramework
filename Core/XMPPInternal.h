//
//  The following is for XMPPStream,
//  and any classes that extend XMPPStream such as XMPPFacebookStream.
//

// Define the various timeouts (in seconds) for retreiving various parts of the XML stream
#define TIMEOUT_XMPP_WRITE         -1
#define TIMEOUT_XMPP_READ_START    10
#define TIMEOUT_XMPP_READ_STREAM   -1

// Define the various tags we'll use to differentiate what it is we're currently reading or writing
#define TAG_XMPP_READ_START         100
#define TAG_XMPP_READ_STREAM        101
#define TAG_XMPP_WRITE_START        200
#define TAG_XMPP_WRITE_STREAM       201
#define TAG_XMPP_WRITE_RECEIPT      202

// Define the various states we'll use to track our progress
enum {
	STATE_XMPP_DISCONNECTED,
	STATE_XMPP_RESOLVING_SRV,
	STATE_XMPP_CONNECTING,
	STATE_XMPP_OPENING,
	STATE_XMPP_NEGOTIATING,
	STATE_XMPP_STARTTLS_1,
	STATE_XMPP_STARTTLS_2,
	STATE_XMPP_POST_NEGOTIATION,
	STATE_XMPP_REGISTERING,
	STATE_XMPP_AUTH_1,
	STATE_XMPP_AUTH_2,
	STATE_XMPP_AUTH_3,
	STATE_XMPP_BINDING,
	STATE_XMPP_START_SESSION,
	STATE_XMPP_CONNECTED,
};

// 
// It is recommended that storage classes cache a stream's myJID.
// This prevents them from constantly querying the property from the xmppStream instance,
// as doing so goes through xmppStream's dispatch queue.
// Caching the stream's myJID frees the dispatch queue to handle xmpp processing tasks.
// 
// The object of the notification will be the XMPPStream instance.
// 
// Note: We're not using the typical MulticastDelegate paradigm for this task as
// storage classes are not typically added as a delegate of the xmppStream.
// 

extern NSString *const XMPPStreamDidChangeMyJIDNotification;
