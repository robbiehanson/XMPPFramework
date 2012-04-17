//
//  This file is for XMPPStream and various internal components.
//

#import "XMPPSASLAuthentication.h"

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
enum XMPPStreamState
{
	STATE_XMPP_DISCONNECTED,
	STATE_XMPP_RESOLVING_SRV,
	STATE_XMPP_CONNECTING,
	STATE_XMPP_OPENING,
	STATE_XMPP_NEGOTIATING,
	STATE_XMPP_STARTTLS_1,
	STATE_XMPP_STARTTLS_2,
	STATE_XMPP_POST_NEGOTIATION,
	STATE_XMPP_REGISTERING,
	STATE_XMPP_AUTH,
	STATE_XMPP_BINDING,
	STATE_XMPP_START_SESSION,
	STATE_XMPP_CONNECTED,
};
typedef enum XMPPStreamState XMPPStreamState;

/**
 * It is recommended that storage classes cache a stream's myJID.
 * This prevents them from constantly querying the property from the xmppStream instance,
 * as doing so goes through xmppStream's dispatch queue.
 * Caching the stream's myJID frees the dispatch queue to handle xmpp processing tasks.
 * 
 * The object of the notification will be the XMPPStream instance.
 * 
 * Note: We're not using the typical MulticastDelegate paradigm for this task as
 * storage classes are not typically added as a delegate of the xmppStream. 
**/
extern NSString *const XMPPStreamDidChangeMyJIDNotification;

@interface XMPPStream (Internal)

@property (readonly) XMPPStreamState state;

/**
 * This method is for use by xmpp authentication mechanism classes.
 * They should send elements using this method instead of the public sendElement classes,
 * as those methods don't send the elements while authentication is in progress.
**/
- (void)sendAuthElement:(NSXMLElement *)element;

@end
