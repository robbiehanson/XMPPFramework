//
// Created by Jonathon Staff on 10/21/14.
// Copyright (c) 2014 nplexity, LLC. All rights reserved.
//

#if !__has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

#import <ifaddrs.h>
#import <net/if.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import "XMPPLogging.h"
#import "XMPPOutgoingFileTransfer.h"
#import "XMPPIDTracker.h"
#import "XMPPConstants.h"
#import "NSNumber+XMPP.h"
#import "NSData+XMPP.h"

#if DEBUG
static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN; // XMPP_LOG_LEVEL_VERBOSE | XMPP_LOG_FLAG_TRACE;
#else
    static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

#define IOS_CELLULAR  @"pdp_ip0"
#define IOS_WIFI      @"en0"
#define IP_ADDR_IPv4  @"ipv4"
#define IP_ADDR_IPv6  @"ipv6"

/**
* Seeing a return statements within an inner block
* can sometimes be mistaken for a return point of the enclosing method.
* This makes inline blocks a bit easier to read.
**/
#define return_from_block return

/**
* Tags for _asyncSocket handling.
*/
#define SOCKS_TAG_READ_METHOD 101
#define SOCKS_TAG_WRITE_METHOD 102
#define SOCKS_TAG_READ_REQUEST 103
#define SOCKS_TAG_READ_DOMAIN 104
#define SOCKS_TAG_WRITE_REPLY 105
#define SOCKS_TAG_WRITE_DATA 106
#define SOCKS_TAG_WRITE_PROXY_METHOD 107
#define SOCKS_TAG_READ_PROXY_METHOD 108
#define SOCKS_TAG_WRITE_PROXY_CONNECT 109
#define SOCKS_TAG_READ_PROXY_REPLY 110

#define TIMEOUT_WRITE -1
#define TIMEOUT_READ 5.0

/**
* Set the default timeout for requests to be 60 seconds.
*/
#define OUTGOING_DEFAULT_TIMEOUT 60

// XMPP Outgoing File Transfer State
typedef NS_ENUM(int, XMPPOFTState) {
  XMPPOFTStateNone,
  XMPPOFTStateStarted,
  XMPPOFTStateSOCKSLive,
  XMPPOFTStateConnectingToProxy,
  XMPPOFTStateFinished
};

NSString *const XMPPOutgoingFileTransferErrorDomain = @"XMPPOutgoingFileTransferErrorDomain";

@interface XMPPOutgoingFileTransfer () {
  dispatch_queue_t _outgoingQueue;
  void *_outgoingQueueTag;

  NSString *_localIPAddress;
  uint16_t _localPort;

  GCDAsyncSocket *_outgoingSocket;

  int32_t _outgoingDataBlockSeq;
  NSUInteger _sentDataSize;
  NSUInteger _totalDataSize;
  NSString *_outgoingDataBase64;

  XMPPOFTState _transferState;

  XMPPJID *_proxyJID;

  NSMutableDictionary *_pastRecipients;
}

@end

@implementation XMPPOutgoingFileTransfer


- (instancetype)initWithDispatchQueue:(dispatch_queue_t)queue
{
  self = [super initWithDispatchQueue:queue];
  if (self) {
    // Create separate dispatch queue.
    _outgoingQueue = dispatch_queue_create("XMPPOutgoingFileTransfer", NULL);
    _outgoingQueueTag = &_outgoingQueueTag;
    dispatch_queue_set_specific(_outgoingQueue, _outgoingQueueTag, _outgoingQueueTag, NULL);

    // define the default block-size in case we use IBB
    _blockSize = 4096;

    _transferState = XMPPOFTStateNone;
    _pastRecipients = [NSMutableDictionary new];
  }
  return self;
}


#pragma mark - XMPPModule Methods

- (void)didActivate
{
  XMPPLogTrace();

  _idTracker = [[XMPPIDTracker alloc] initWithStream:xmppStream dispatchQueue:moduleQueue];
}

- (void)willDeactivate
{
  XMPPLogTrace();

  [_idTracker removeAllIDs];
  _idTracker = nil;
}

#pragma mark - Public Methods

- (BOOL)startFileTransfer:(NSError **)errPtr
{
  XMPPLogTrace();

  if (!xmppStream.isConnected) {
    if (errPtr) {
      NSString *errMsg = @"You must be connected to send a file";
      *errPtr = [self localErrorWithMessage:errMsg code:-1];
    }

    return NO;
  }

  if (!_outgoingData) {
    if (errPtr) {
      NSString *errMsg = @"You must provide data to be sent.";
      *errPtr = [self localErrorWithMessage:errMsg code:-1];
    }

    return NO;
  }

  if (!_recipientJID || ![_recipientJID isFull]) {
    if (errPtr) {
      NSString *errMsg = @"You must provide a recipient (including a resource).";
      *errPtr = [self localErrorWithMessage:errMsg code:-1];
    }

    return NO;
  }

  if (self.disableSOCKS5 && self.disableIBB) {
    if (errPtr) {
      NSString *errMsg = @"Both SOCKS5 and IBB transfers are disabled.";
      *errPtr = [self localErrorWithMessage:errMsg code:-1];
    }

    return NO;
  }

  if (_transferState != XMPPOFTStateNone) {
    if (errPtr) {
      NSString *errMsg = @"Transfer already in progress.";
      *errPtr = [self localErrorWithMessage:errMsg code:-1];
    }

    return NO;
  }

  dispatch_block_t block = ^{
      @autoreleasepool {
        _transferState = XMPPOFTStateStarted;

        if (_pastRecipients[_recipientJID.full]) {
          uint8_t methods = [_pastRecipients[_recipientJID.full] unsignedIntValue];

          if (methods & XMPPFileTransferStreamMethodBytestreams) {
            _streamMethods |= XMPPFileTransferStreamMethodBytestreams;
          }

          if (methods & XMPPFileTransferStreamMethodIBB) {
            _streamMethods |= XMPPFileTransferStreamMethodIBB;
          }

          if (_streamMethods) {
            [self querySIOffer];
            return_from_block;
          }
        }

        [self queryRecipientDiscoInfo];
      }
  };

  if (dispatch_get_specific(moduleQueueTag))
    block();
  else
    dispatch_async(moduleQueue, block);

  return YES;
}

- (BOOL)sendData:(NSData *)data toRecipient:(XMPPJID *)recipient
{
  return _transferState != XMPPOFTStateNone ? NO : [self sendData:data
                                                            named:nil
                                                      toRecipient:recipient
                                                      description:nil
                                                            error:nil];

}

- (BOOL)sendData:(NSData *)data
           named:(NSString *)name
     toRecipient:(XMPPJID *)recipient
     description:(NSString *)description
           error:(NSError **)errPtr
{
  if (_transferState != XMPPOFTStateNone) {
    if (errPtr) {
      NSString *errMsg = @"Transfer already in progress.";
      *errPtr = [self localErrorWithMessage:errMsg code:-1];
    }

    return NO;
  }

  self.outgoingData = data;
  self.outgoingFileName = name;
  self.recipientJID = recipient;
  self.outgoingFileDescription = description;

  return [self startFileTransfer:errPtr];
}


#pragma mark - Private Methods

/**
* This method sends a `disco#info` query to the recipient. This is done to
* ensure they support file transfer, SOCKS5, and IBB.
*
* The request will look like the following:
*
* <iq xmlns="jabber:client"
*     from="deckardcain@sanctuary.org/tristram"
*     to="tyrael@sanctuary.org/talrashastomb"
*     type="get"
*     id="purplea2da8fc9">
*   <query xmlns="http://jabber.org/protocol/disco#info"/>
* </iq>
*
* @see handleRecipientDiscoInfoQueryIQ:withInfo:
*/
- (void)queryRecipientDiscoInfo
{
  XMPPLogTrace();

  dispatch_block_t block = ^{
      @autoreleasepool {
        XMPPIQ *iq = [XMPPIQ iqWithType:@"get"
                                     to:_recipientJID
                              elementID:[xmppStream generateUUID]];
        NSXMLElement *query = [NSXMLElement elementWithName:@"query"
                                                      xmlns:XMPPDiscoInfoNamespace];
        [iq addChild:query];

        [_idTracker addElement:iq
                        target:self
                      selector:@selector(handleRecipientDiscoInfoQueryIQ:withInfo:)
                       timeout:OUTGOING_DEFAULT_TIMEOUT];

        [xmppStream sendElement:iq];
      }
  };

  if (dispatch_get_specific(moduleQueueTag))
    block();
  else
    dispatch_async(moduleQueue, block);
}

/**
* This method is responsible for sending the Stream Initiation Offer as
* described in Examples 1 and 3 of XEP-0096. Both SOCKS5 bytestreams (XEP-0065)
* and IBB (XEP-0047) are sent as options. The default, per XEP-0096 3.1, is
* SOCKS5, with IBB as the fallback.
*
* The outgoing IQ will be similar to the one below:
*
* <iq xmlns="jabber:client"
*     from="deckardcain@sanctuary.org/tristram"
*     to="tyrael@sanctuary.org/talrashastomb"
*     type="set"
*     id="purplea2da8fca">
*   <si xmlns="http://jabber.org/protocol/si"
*       id="purplea2da8fcb"
*       profile="http://jabber.org/protocol/si/profile/file-transfer">
*     <file xmlns="http://jabber.org/protocol/si/profile/file-transfer"
*           name="Baal's Soulstone.jpg"
*           size="433362">
*       <desc>We should destroy this, right?</desc>
*     </file>
*     <feature xmlns="http://jabber.org/protocol/feature-neg">
*       <x xmlns="jabber:x:data" type="form">
*         <field var="stream-method" type="list-single">
*           <option>
*             <value>http://jabber.org/protocol/bytestreams</value>
*           </option>
*           <option>
*             <value>http://jabber.org/protocol/ibb</value>
*           </option>
*         </field>
*       </x>
*     </feature>
*   </si>
* </iq>
*
* @see handleSIOfferQueryIQ:withInfo:
*/
- (void)querySIOffer
{
  XMPPLogTrace();

  dispatch_block_t block = ^{
      @autoreleasepool {
        XMPPIQ *iq = [XMPPIQ iqWithType:@"set"
                                     to:_recipientJID
                              elementID:[xmppStream generateUUID]];
        [iq addAttributeWithName:@"from" stringValue:xmppStream.myJID.full];

        // Store the sid; we'll need this later
        self.sid = [xmppStream generateUUID];

        NSXMLElement *si = [NSXMLElement elementWithName:@"si" xmlns:XMPPSINamespace];
        [si addAttributeWithName:@"id" stringValue:self.sid];
        [si addAttributeWithName:@"profile" stringValue:XMPPSIProfileFileTransferNamespace];
        [iq addChild:si];

        // Generate a random filename if one isn't provided
        NSString *fileName;
        if (_outgoingFileName) {

          // If there is a name provided, but a random one should be created, we'll keep the file ext.
          if (_shouldGenerateRandomName) {
            NSString *ext = [[_outgoingFileName componentsSeparatedByString:@"."] lastObject];
            fileName = [NSString stringWithFormat:@"%@.%@", [xmppStream generateUUID], ext];
          } else {
            fileName = _outgoingFileName;
          }
        } else {
          fileName = [xmppStream generateUUID];
        }

        NSXMLElement *file = [NSXMLElement elementWithName:@"file"
                                                     xmlns:XMPPSIProfileFileTransferNamespace];
        [file addAttributeWithName:@"name" stringValue:fileName];
        [file addAttributeWithName:@"size"
                       stringValue:[[NSString alloc] initWithFormat:@"%lu",
                                                                    (unsigned long) [_outgoingData length]]];//TODO
        [si addChild:file];

        // Only include description if it's provided
        if (_outgoingFileDescription) {
          NSXMLElement *desc = [NSXMLElement elementWithName:@"desc"
                                                 stringValue:_outgoingFileDescription];
          [file addChild:desc];
        }

        NSXMLElement *feature = [NSXMLElement elementWithName:@"feature"
                                                        xmlns:XMPPFeatureNegNamespace];
        [si addChild:feature];

        NSXMLElement *x = [NSXMLElement elementWithName:@"x" xmlns:@"jabber:x:data"];
        [x addAttributeWithName:@"type" stringValue:@"form"];
        [feature addChild:x];

        NSXMLElement *field = [NSXMLElement elementWithName:@"field"];
        [field addAttributeWithName:@"var" stringValue:@"stream-method"];
        [field addAttributeWithName:@"type" stringValue:@"list-single"];
        [x addChild:field];

        // We support SOCKS5
        if (!self.disableSOCKS5) {
          NSXMLElement *option = [NSXMLElement elementWithName:@"option"];
          [field addChild:option];
          NSXMLElement *value = [NSXMLElement elementWithName:@"value"
                                                  stringValue:XMPPBytestreamsNamespace];
          [option addChild:value];
        }

        // We support IBB
        if (!self.disableIBB) {
          NSXMLElement *option2 = [NSXMLElement elementWithName:@"option"];
          [field addChild:option2];
          NSXMLElement *value2 = [NSXMLElement elementWithName:@"value"
                                                   stringValue:XMPPIBBNamespace];
          [option2 addChild:value2];
        }

        [_idTracker addElement:iq
                        target:self
                      selector:@selector(handleSIOfferQueryIQ:withInfo:)
                       timeout:OUTGOING_DEFAULT_TIMEOUT];

        [xmppStream sendElement:iq];
      }
  };

  if (dispatch_get_specific(moduleQueueTag))
    block();
  else
    dispatch_async(moduleQueue, block);
}

/**
* This method begins the process of collecting streamhosts to send to the
* recipient. The first (and preferred) streamhost is the sender's local
* IP Address and a random local port. If the recipient is able to connect
* using this streamhost, the bytestream should be directly between clients and
* not require the use of a proxy.
*/
- (void)collectStreamHosts
{
  XMPPLogTrace();

  dispatch_block_t block = ^{
      @autoreleasepool {
        _localIPAddress = [self getIPAddress:YES];

        if (!_localPort) {
          _localPort = [XMPPOutgoingFileTransfer getRandomPort];
        }

        _streamhosts = [NSMutableArray new];

        // Don't send direct streamhost details if disabled.
        if (!self.disableDirectTransfers) {
          NSXMLElement *streamHost = [NSXMLElement elementWithName:@"streamhost"];
          [streamHost addAttributeWithName:@"jid" stringValue:xmppStream.myJID.full];
          [streamHost addAttributeWithName:@"host" stringValue:_localIPAddress];
          [streamHost addAttributeWithName:@"port" intValue:_localPort];
          [_streamhosts addObject:streamHost];
        }

        [self queryProxyDiscoItems];
      }
  };

  if (dispatch_get_specific(moduleQueueTag))
    block();
  else
    dispatch_async(moduleQueue, block);
}

/**
* This method queries the server to determine what its services are, hopefully
* finding that one of them is a proxy. A `disco#items` query is sent to the
* domain of the file transfer initiator.
*
* @see handleProxyDiscoItemsQueryIQ:withInfo:
*/
- (void)queryProxyDiscoItems
{
  XMPPLogTrace();

  dispatch_block_t block = ^{
      @autoreleasepool {
        NSString *toStr = xmppStream.myJID.domain;
        NSXMLElement *query = [NSXMLElement elementWithName:@"query"
                                                      xmlns:XMPPDiscoItemsNamespace];
        XMPPIQ *iq = [XMPPIQ iqWithType:@"get"
                                     to:[XMPPJID jidWithString:toStr]
                              elementID:[xmppStream generateUUID]
                                  child:query];

        [_idTracker addElement:iq
                        target:self
                      selector:@selector(handleProxyDiscoItemsQueryIQ:withInfo:)
                       timeout:OUTGOING_DEFAULT_TIMEOUT];

        [xmppStream sendElement:iq];
      }
  };

  if (dispatch_get_specific(moduleQueueTag))
    block();
  else
    dispatch_async(moduleQueue, block);
}

/**
* This method queries a JID directly to determine whether or not it is a proxy
* service. The provided JID will be in the form `subdomain.domain.com`, likely
* `proxy.domain.com`. This method will be called for each service found at the
* initiator's server until a proxy service is found or all services have been
* exhausted.
*
* @see handleProxyDiscoInfoQueryIQ:withInfo:
*/
- (void)queryProxyDiscoInfoWithJID:(XMPPJID *)jid
{
  XMPPLogTrace();

  dispatch_block_t block = ^{
      @autoreleasepool {
        XMPPIQ *iq = [XMPPIQ iqWithType:@"get"
                                     to:jid
                              elementID:[xmppStream generateUUID]];
        NSXMLElement *query = [NSXMLElement elementWithName:@"query"
                                                      xmlns:XMPPDiscoInfoNamespace];
        [iq addChild:query];

        [_idTracker addElement:iq
                        target:self
                      selector:@selector(handleProxyDiscoInfoQueryIQ:withInfo:)
                       timeout:OUTGOING_DEFAULT_TIMEOUT];

        [xmppStream sendElement:iq];
      }
  };

  if (dispatch_get_specific(moduleQueueTag))
    block();
  else
    dispatch_async(moduleQueue, block);
}

/**
* This method queries a JID directly to determine its address and port. It has
* already been established that the provided JID is indeed a proxy. We merely
* need to know how to connect.
*
* @see handleProxyAddressQueryIQ:withInfo:
*/
- (void)queryProxyAddressWithJID:(XMPPJID *)jid
{
  XMPPLogTrace();

  dispatch_block_t block = ^{
      @autoreleasepool {
        XMPPIQ *iq = [XMPPIQ iqWithType:@"get"
                                     to:jid
                              elementID:[xmppStream generateUUID]];
        NSXMLElement *query = [NSXMLElement elementWithName:@"query"
                                                      xmlns:XMPPBytestreamsNamespace];
        [iq addChild:query];

        [_idTracker addElement:iq
                        target:self
                      selector:@selector(handleProxyAddressQueryIQ:withInfo:)
                       timeout:OUTGOING_DEFAULT_TIMEOUT];

        [xmppStream sendElement:iq];
      }
  };

  if (dispatch_get_specific(moduleQueueTag))
    block();
  else
    dispatch_async(moduleQueue, block);
}

/**
* This method sends the list of streamhosts to the recipient and waits for a
* connection on one of them.
*
* One of these streamhosts will be a local IP address of the sender. If either
* or both of the parties are behind a Network Address Translation (NAT) device,
* this will not work (provided that they aren't on the same Local Area Network
* (LAN). In theory, this means that if both devices are on cellular data, they
* should be able to establish a direct connection. If one (or both) are on wifi,
* either a proxy streamhost will have to be used or IBB will have to be used.
*/
- (void)sendStreamHostsAndWaitForConnection
{
  XMPPLogTrace();

  dispatch_block_t block = ^{
      @autoreleasepool {
        if (_streamhosts.count < 1) {
          NSString *errMsg =
              [NSString stringWithFormat:@"Unable to send streamhosts to %@", _recipientJID.full];
          [self failWithReason:errMsg error:nil];
          return;
        }

        XMPPIQ *iq = [XMPPIQ iqWithType:@"set"
                                     to:_recipientJID
                              elementID:[xmppStream generateUUID]];
        [iq addAttributeWithName:@"xmlns" stringValue:@"jabber:client"];
        [iq addAttributeWithName:@"from" stringValue:xmppStream.myJID.full];

        NSXMLElement *query = [NSXMLElement elementWithName:@"query"
                                                      xmlns:XMPPBytestreamsNamespace];
        [query addAttributeWithName:@"sid" stringValue:self.sid];

        for (NSXMLElement *streamhost in _streamhosts) {
          [streamhost detach];
          [query addChild:streamhost];
        }

        [iq addChild:query];

        [_idTracker addElement:iq
                        target:self
                      selector:@selector(handleSentStreamhostsQueryIQ:withInfo:)
                       timeout:OUTGOING_DEFAULT_TIMEOUT];

        // Send the list of streamhosts to the recipient
        [xmppStream sendElement:iq];

        // Create a socket to listen for a direct connection
        if (!_asyncSocket) {
          _asyncSocket = [[GCDAsyncSocket alloc] initWithDelegate:self
                                                    delegateQueue:moduleQueue];
        }

        NSError *error;

        if (![_asyncSocket acceptOnPort:_localPort error:&error]) {
          NSString *errMsg = [NSString stringWithFormat:@"Failed to open port %d", _localPort];
          [self failWithReason:errMsg error:error];
        }
      }
  };

  if (dispatch_get_specific(moduleQueueTag))
    block();
  else
    dispatch_async(moduleQueue, block);
}


#pragma mark - IBB Transfer

/**
* This method is responsible for opening a new In-Band Bytestream, as shown in
* XEP-0047 Example 1. We *MUST* send the same sid inside the <open /> stanza
* that was used in the SI offer.
*
* The outgoing IQ will be similar to the following:
*
* <iq from='deckardcain@sanctuary.org/tristram'
*     id='jn3h8g65'
*     to='tyrael@sanctuary.org/talrashastomb'
*     type='set'>
*   <open xmlns='http://jabber.org/protocol/ibb'
*         block-size='4096'
*         sid='i781hf64'
*         stanza='iq'/>
* </iq>
*
* @see handleInitialIBBQueryIQ:withInfo:
*/
- (void)beginIBBTransfer
{

  XMPPLogTrace();

  dispatch_block_t block = ^{
      @autoreleasepool {
        XMPPIQ *iq = [XMPPIQ iqWithType:@"set"
                                     to:_recipientJID
                              elementID:[xmppStream generateUUID]];

        NSXMLElement *open = [NSXMLElement elementWithName:@"open" xmlns:XMPPIBBNamespace];
        [open addAttributeWithName:@"block-size" intValue:_blockSize];
        [open addAttributeWithName:@"sid" stringValue:self.sid];
        [open addAttributeWithName:@"stanza" stringValue:@"iq"];
        [iq addChild:open];

        [_idTracker addElement:iq
                        target:self
                      selector:@selector(handleInitialIBBQueryIQ:withInfo:)
                       timeout:OUTGOING_DEFAULT_TIMEOUT];

        [xmppStream sendElement:iq];

        // Convert our data to base64 for the IBB transmission
        _outgoingDataBase64 = [_outgoingData base64EncodedStringWithOptions:0];
        _totalDataSize = _outgoingDataBase64.length;
      }
  };

  if (dispatch_get_specific(moduleQueueTag))
    block();
  else
    dispatch_async(moduleQueue, block);
}

/**
* This method handles the response to a query matching Example 1. Initiator
* requests session (XEP-0047).
*
* @see beginIBBTransfer
*
* The possible responses are described in Examples 2-5 of XEP-0047.
*/
- (void)handleInitialIBBQueryIQ:(XMPPIQ *)iq withInfo:(XMPPBasicTrackingInfo *)info
{
  XMPPLogTrace();

  dispatch_block_t block = ^{
      @autoreleasepool {
        if (!iq) {
          // If we're inside this block, it means that the timeout has been
          // fired and we need to force a failure
          NSString *errMsg = @"Timeout waiting for response to IBB intiation.";
          [self failWithReason:errMsg error:nil];
        }

        NSXMLElement *errorElem = [iq elementForName:@"error"];

        if (errorElem) {
          NSString *errType = [errorElem attributeStringValueForName:@"type"];

          // Handle Example 3 and 5
          if ([errType isEqualToString:@"cancel"]) {
            NSString *errMsg = [NSString stringWithFormat:@"Error initiating IBB: %@",
                                                          [errorElem childAtIndex:0].name];
            [self failWithReason:errMsg error:nil];
            return_from_block;
          }

          // Handle Example 4. We'll divide the block-size by 4 and try again.
          if ([errType isEqualToString:@"modify"]
              && [[errorElem childAtIndex:0].name isEqualToString:@"resource-constraint"]) {
            XMPPLogInfo(@"Responder prefers smaller IBB chunks. Shrinking block-size and retrying");
            _blockSize /= 2;
            [self beginIBBTransfer];
            return_from_block;
          }
        }

        // Handle Example 2. Responder accepts session
        if (iq.childCount == 0) {
          XMPPLogVerbose(@"Responder has accepted IBB session. Begin sending data");
          [self sendIBBData];
        }
      }
  };

  if (dispatch_get_specific(moduleQueueTag))
    block();
  else
    dispatch_async(moduleQueue, block);
}

/**
* Sends the data to the recipient via IBB. This method will continue until it
* has verified that all the data has been sent, it fails, or receives an error
* from the recipient. It will close the IBB stream upon completion.
*
* Example 6. Sending data in an IQ stanza (XEP-0047)
*
* <iq from='deckardcain@sanctuary.org/tristram'
*     id='kr91n475'
*     to='tyrael@sanctuary.org/talrashastomb'
*     type='set'>
*   <data xmlns='http://jabber.org/protocol/ibb' seq='0' sid='i781hf64'>
*     qANQR1DBwU4DX7jmYZnncmUQB/9KuKBddzQH+tZ1ZywKK0yHKnq57kWq+RFtQdCJ
*     WpdWpR0uQsuJe7+vh3NWn59/gTc5MDlX8dS9p0ovStmNcyLhxVgmqS8ZKhsblVeu
*     IpQ0JgavABqibJolc3BKrVtVV1igKiX/N7Pi8RtY1K18toaMDhdEfhBRzO/XB0+P
*     AQhYlRjNacGcslkhXqNjK5Va4tuOAPy2n1Q8UUrHbUd0g+xJ9Bm0G0LZXyvCWyKH
*     kuNEHFQiLuCY6Iv0myq6iX6tjuHehZlFSh80b5BVV9tNLwNR5Eqz1klxMhoghJOA
*   </data>
* </iq>
*
* @see handleIBBTransferQueryIQ:withInfo:
*/
- (void)sendIBBData
{
  XMPPLogTrace();

  dispatch_block_t block = ^{
      @autoreleasepool {
        if (_sentDataSize < _totalDataSize) {
          XMPPIQ *iq = [XMPPIQ iqWithType:@"set"
                                       to:_recipientJID
                                elementID:[xmppStream generateUUID]];
          NSXMLElement *data = [NSXMLElement elementWithName:@"data" xmlns:XMPPIBBNamespace];
          [data addAttributeWithName:@"sid" stringValue:self.sid];
          [data addAttributeWithName:@"seq" intValue:_outgoingDataBlockSeq++];

          // Get the base64 data for our block
          NSUInteger length = _sentDataSize + _blockSize > _totalDataSize ?
              _totalDataSize - _sentDataSize : _blockSize;
          NSRange range = NSMakeRange(_sentDataSize, length);

          NSString *dataString = [_outgoingDataBase64 substringWithRange:range];
          XMPPLogVerbose(@"Uploading %lu/%lu bytes in IBB transfer.", (unsigned long) _sentDataSize,
                         (unsigned long) _totalDataSize);

          [data setStringValue:dataString];
          [iq addChild:data];

          [_idTracker addElement:iq
                          target:self
                        selector:@selector(handleIBBTransferQueryIQ:withInfo:)
                         timeout:OUTGOING_DEFAULT_TIMEOUT];

          [xmppStream sendElement:iq];
        } else {
          XMPPLogInfo(@"IBB file transfer complete. Closing stream...");

          // All the data has been sent. Alert the delegate that the transfer
          // was successful and close the stream.
          [multicastDelegate xmppOutgoingFileTransferDidSucceed:self];
          [self closeIBB];
        }
      }
  };

  if (dispatch_get_specific(moduleQueueTag))
    block();
  else
    dispatch_async(moduleQueue, block);
}

/**
* Handles the response from the data recipient during an IBB file transfer. The
* recipient should be sending back a childless result IQ confirming that they
* received the data we sent. We will wait until receiving this IQ before
* sending the next block of data.
*
* Example 7. Acknowledging data received via IQ (XEP-0047)
*
* <iq from='tyrael@sanctuary.org/talrashastomb'
*     id='kr91n475'
*     to='deckardcain@sanctuary.org/tristram'
*     type='result'/>
*
* @see sendIBBData
*/
- (void)handleIBBTransferQueryIQ:(XMPPIQ *)iq withInfo:(XMPPBasicTrackingInfo *)info
{
  XMPPLogTrace();

  dispatch_block_t block = ^{
      @autoreleasepool {
        if (!iq) {
          // If we're inside this block, it means that the timeout has been
          // fired and we need to force a failure
          NSString *errMsg = @"Timeout waiting for response to IBB sent data.";
          [self failWithReason:errMsg error:nil];
        }

        NSXMLElement *errorElem = [iq elementForName:@"error"];

        // Handle dropped connection or recipient offline.
        if (errorElem) {
          NSString *errMsg = [NSString stringWithFormat:@"Error transferring with IBB: %@",
                                                        [errorElem childAtIndex:0]];
          NSError *err = [self localErrorWithMessage:errMsg code:-1];

          NSString *reason =
              @"The recipient might be offline, the connection was interrupted, or the transfer was canceled.";
          [self failWithReason:reason error:err];
          return;
        }

        // Handle the scenario when the recipient closes the bytestream.
        NSXMLElement *close = [iq elementForName:@"close"];
        if (close) {
          if (_sentDataSize >= _totalDataSize) {
            // We can assume the transfer was successful.
            [multicastDelegate xmppOutgoingFileTransferDidSucceed:self];
            [multicastDelegate xmppOutgoingFileTransferIBBClosed:self];

            // As per Examples 8-9 (XEP-0047), we SHOULD send the following
            // response to let the other party know it's alright to close the
            // bytestream. There's no reason to track it, however.
            //
            // <iq from='tyrael@sanctuary.org/talrashastomb'
            //     id='us71g45j'
            //     to='deckardcain@sanctuary.org/tristram'
            //     type='result'/>

            XMPPIQ *resultIq = [XMPPIQ iqWithType:@"result"
                                               to:_recipientJID
                                        elementID:iq.elementID];
            [xmppStream sendElement:resultIq];
          } else {
            // There must have been a reason to close, but we don't know it.
            // Therefore, the transfer might not have been successful.
            [self failWithReason:@"Recipient closed IBB stream." error:nil];
            [multicastDelegate xmppOutgoingFileTransferIBBClosed:self];
          }
        }

        // At this point, we're assuming that we've received the stanza shown
        // above and the recipient has successfully received the data we sent,
        // so we should now send them the next block of data.
        _sentDataSize += _blockSize;
        [self sendIBBData];

        XMPPLogVerbose(
            @"Received response signifying successful IBB stanza. Sending the next block");
      }
  };

  if (dispatch_get_specific(moduleQueueTag))
    block();
  else
    dispatch_async(moduleQueue, block);
}

/**
* XEP-0047 Example 8. Closing the bytestream
*
* Sends an IQ to the recipient stating that the bytestream will be closed. As
* per the protocol, we SHOULD wait for an IQ response before we can consider
* the bytestream to be closed.
*
* Note that the 'sid' must be included.
*
* @see handleCloseIBBQueryIQ:withInfo:
*/
- (void)closeIBB
{
  XMPPLogTrace();

  dispatch_block_t block = ^{
      @autoreleasepool {
        XMPPIQ *iq = [XMPPIQ iqWithType:@"set"
                                     to:_recipientJID
                              elementID:[xmppStream generateUUID]];
        NSXMLElement *close = [NSXMLElement elementWithName:@"close" xmlns:XMPPIBBNamespace];
        [close addAttributeWithName:@"sid" stringValue:self.sid];
        [iq addChild:close];

        [_idTracker addElement:iq
                        target:self
                      selector:@selector(handleCloseIBBQueryIQ:withInfo:)
                       timeout:OUTGOING_DEFAULT_TIMEOUT];

        [xmppStream sendElement:iq];
      }
  };

  if (dispatch_get_specific(moduleQueueTag))
    block();
  else
    dispatch_async(moduleQueue, block);
}

/**
* Handles the response of our query to close the IBB. When it gets a response,
* it merely changes the state and logs that the stream is closed. a successful
* response will look like XEP-0047 Example 9.
*/
- (void)handleCloseIBBQueryIQ:(XMPPIQ *)iq withInfo:(XMPPBasicTrackingInfo *)info
{
  XMPPLogTrace();

  dispatch_block_t block = ^{
      @autoreleasepool {
        if (!iq) {
          // If we're inside this block, it means that the timeout has been
          // fired and we need to force a failure
          NSString *errMsg = @"Timeout waiting for close IBB response.";
          [self failWithReason:errMsg error:nil];
        }

        // The protocol states that we might receive an <item-not-found />
        // response, so we'll just ignore that here
        NSXMLElement *errorElem = [iq elementForName:@"error"];
        if (errorElem && ![errorElem.name isEqualToString:@"item-not-found"]) {
          NSString *errMsg = [errorElem.children componentsJoinedByString:@", "];
          NSError *err = [self localErrorWithMessage:errMsg
                                                code:[errorElem attributeIntValueForName:@"code"]];
          [self failWithReason:errMsg error:err];
          return_from_block;
        }

        // We're assuming that if it makes it this far, it's the response we want
        [multicastDelegate xmppOutgoingFileTransferIBBClosed:self];
      }
  };

  if (dispatch_get_specific(moduleQueueTag))
    block();
  else
    dispatch_async(moduleQueue, block);
}


#pragma mark - Response Handling

/**
* This method handles the response of our `disco#info` query sent to the file
* recipient. We ensure that the recipient has the capabilities for our transfer
* before sending an SI offer.
*
* <iq type="result"
*     id="purplea2da8fc9"
*     from="tyrael@sanctuary.org/talrashastomb"
*     to="deckardcain@sanctuary.org/tristram">
*   <query xmlns="http://jabber.org/protocol/disco#info">
*     <identity category="client" type="phone"/>
*     <feature var="http://jabber.org/protocol/si"/>
*     <feature var="http://jabber.org/protocol/si/profile/file-transfer"/>
*     <feature var="http://jabber.org/protocol/bytestreams"/>
*   </query>
* </iq>
*
*/
- (void)handleRecipientDiscoInfoQueryIQ:(XMPPIQ *)iq withInfo:(XMPPBasicTrackingInfo *)info
{
  XMPPLogTrace();
  XMPPLogInfo(@"iq: %@, info: %@", iq, info);

  dispatch_block_t block = ^{
      @autoreleasepool {
        if (!iq) {
          // If we're inside this block, it means that the timeout has been
          // fired and we need to force a failure
          NSString *errMsg = @"Timeout waiting for recipient `disco#info` response.";
          [self failWithReason:errMsg error:nil];
        }

        NSXMLElement *errorElem = [iq elementForName:@"error"];

        if (errorElem) {
          NSString *errMsg = [errorElem.children componentsJoinedByString:@", "];
          NSError *err = [self localErrorWithMessage:errMsg
                                                code:[errorElem attributeIntValueForName:@"code"]];
          [self failWithReason:errMsg error:err];
          return_from_block;
        }

        NSXMLElement *query = [iq elementForName:@"query"];

        // We're checking to see if the recipient has the features we need
        BOOL hasSI = NO;
        BOOL hasFT = NO;
        BOOL hasSOCKS5 = NO;
        BOOL hasIBB = NO;

        NSArray *features = [query elementsForName:@"feature"];
        for (NSXMLElement *feature in features) {
          NSString *var = [feature attributeStringValueForName:@"var"];
          if ([var isEqualToString:XMPPSINamespace]) hasSI = YES;
          if ([var isEqualToString:XMPPSIProfileFileTransferNamespace]) hasFT = YES;
          if ([var isEqualToString:XMPPBytestreamsNamespace]) hasSOCKS5 = YES;
          if ([var isEqualToString:XMPPIBBNamespace]) hasIBB = YES;
        }

        hasSOCKS5 = hasSI && hasFT && hasSOCKS5;
        hasIBB = hasSI && hasFT && hasIBB;

        if (!hasSOCKS5 || !hasIBB) {
          NSString *errMsg =
              @"Unable to send SI offer; the recipient doesn't have the required features.";
          XMPPLogInfo(@"%@: %@", THIS_FILE, errMsg);

          NSError *err = [self localErrorWithMessage:errMsg code:-1];
          [multicastDelegate xmppOutgoingFileTransfer:self didFailWithError:err];

          return_from_block;
        }

        [self querySIOffer];

        // TODO:
        // The following lines are currently useless. Maybe at some point I'll
        // add the ability to restart the transfer using IBB if bytestreams
        // fail, but only if the stream-method is available.
        if (hasSOCKS5) {
          _streamMethods |= XMPPFileTransferStreamMethodBytestreams;
        }

        if (hasIBB) {
          _streamMethods |= XMPPFileTransferStreamMethodIBB;
        }

        _pastRecipients[_recipientJID.full] = @(_streamMethods);
      }
  };

  if (dispatch_get_specific(moduleQueueTag))
    block();
  else
    dispatch_async(moduleQueue, block);
}

/**
* This method is responsible for handling the response to the Stream Initiation
* Offer that will be in the form described in Examples 2 and 4 of XEP-0096.
* Depending on the response, this method will trigger an error or begin the
* transfer process using either SOCKS5 or IBB (whichever is sent back first).
*
* The response should be in a similar format to that which is shown below:
*
* <iq type="result"
*     id="purplea2da8fca"
*     from="tyrael@sanctuary.org/talrashastomb"
*     to="deckardcain@sanctuary.org/tristram">
*   <si xmlns="http://jabber.org/protocol/si">
*     <feature xmlns="http://jabber.org/protocol/feature-neg">
*       <x xmlns="jabber:x:data" type="submit">
*         <field var="stream-method">
*           <value>http://jabber.org/protocol/bytestreams</value>
*         </field>
*       </x>
*     </feature>
*   </si>
* </iq>
*/
- (void)handleSIOfferQueryIQ:(XMPPIQ *)iq withInfo:(XMPPBasicTrackingInfo *)info
{
  XMPPLogTrace();

  dispatch_block_t block = ^void {
      @autoreleasepool {
        if (!iq) {
          // If we're inside this block, it means that the timeout has been
          // fired and we need to force a failure
          NSString *errMsg = @"Timeout waiting for SI offer response.";
          [self failWithReason:errMsg error:nil];
        }

        NSXMLElement *errorElem = [iq elementForName:@"error"];

        if (errorElem) {
          NSString *errMsg = [errorElem.children componentsJoinedByString:@", "];
          NSError *err = [self localErrorWithMessage:errMsg
                                                code:[errorElem attributeIntValueForName:@"code"]];
          [self failWithReason:@"There was an issue with the SI offer." error:err];
          return_from_block;
        }

        NSXMLElement *si = iq.childElement;
        NSXMLElement *feature = (NSXMLElement *) [si childAtIndex:0];
        NSXMLElement *x = (NSXMLElement *) [feature childAtIndex:0];
        NSXMLElement *field = (NSXMLElement *) [x childAtIndex:0];
        NSXMLElement *value = (NSXMLElement *) [field childAtIndex:0];

        if ([[value stringValue] isEqualToString:XMPPBytestreamsNamespace]) {
          XMPPLogVerbose(@"The recipient has confirmed the use of SOCKS5. Starting transfer...");
          [self collectStreamHosts];
        } else if ([[value stringValue] isEqualToString:XMPPIBBNamespace]) {
          XMPPLogVerbose(@"The recipient has confirmed the use of IBB. Beginning IBB transfer");
          [self beginIBBTransfer];
        }
      }
  };

  if (dispatch_get_specific(moduleQueueTag))
    block();
  else
    dispatch_async(moduleQueue, block);
}

/**
* This method handles the server's response to the `disco#items` query sent
* before. It iterates through the results and queries each JID to determine
* whether or not it is a proxy service.
*
* @see queryProxyDiscoInfoWithJID:
*/
- (void)handleProxyDiscoItemsQueryIQ:(XMPPIQ *)iq withInfo:(XMPPBasicTrackingInfo *)info
{
  XMPPLogTrace();

  dispatch_block_t block = ^{
      @autoreleasepool {
        if (!iq) {
          // If we're inside this block, it means that the timeout has been
          // fired and we need to force a failure
          NSString *errMsg = @"Timeout waiting for proxy `disco#items` response.";
          [self failWithReason:errMsg error:nil];
        }

        NSXMLElement *errorElem = [iq elementForName:@"error"];

        if (errorElem) {
          NSString *errMsg = [errorElem.children componentsJoinedByString:@", "];
          NSError *err = [self localErrorWithMessage:errMsg
                                                code:[errorElem attributeIntValueForName:@"code"]];
          [self failWithReason:@"There was an error with the disco#items request." error:err];
          return_from_block;
        }

        NSXMLElement *query = [iq elementForName:@"query" xmlns:XMPPDiscoItemsNamespace];
        if (!query) return;

        NSArray *items = [query elementsForName:@"item"];

        for (NSXMLElement *item in items) {
          XMPPJID *itemJid = [XMPPJID jidWithString:[item attributeStringValueForName:@"jid"]];

          if (itemJid) {
            XMPPLogVerbose(@"Found service %@. Querying to see if it's a proxy.", itemJid.full);
            [self queryProxyDiscoInfoWithJID:itemJid];
          }
        }
      }
  };

  if (dispatch_get_specific(moduleQueueTag))
    block();
  else
    dispatch_async(moduleQueue, block);
}

/**
* This method handles the server's response to the `disco#info` query sent
* before. It determines whether or not the service is indeed a proxy. If it is,
* the service is queried for its address and port.
*
* @see queryProxyAddressWithJID
*/
- (void)handleProxyDiscoInfoQueryIQ:(XMPPIQ *)iq withInfo:(XMPPBasicTrackingInfo *)info
{
  XMPPLogTrace();

  dispatch_block_t block = ^{
      @autoreleasepool {
        if (!iq) {
          // If we're inside this block, it means that the timeout has been
          // fired and we need to force a failure
          NSString *errMsg = @"Timeout waiting for proxy `disco#info` response.";
          [self failWithReason:errMsg error:nil];
        }

        NSXMLElement *errorElem = [iq elementForName:@"error"];

        if (errorElem) {
          NSString *errMsg = [errorElem.children componentsJoinedByString:@", "];
          NSError *err = [self localErrorWithMessage:errMsg
                                                code:[errorElem attributeIntValueForName:@"code"]];
          [self failWithReason:@"There was an error with the disco#info request." error:err];
          return_from_block;
        }

        NSXMLElement *query = [iq elementForName:@"query" xmlns:XMPPDiscoInfoNamespace];
        NSArray *identities = [query elementsForName:@"identity"];

        for (NSXMLElement *identity in identities) {
          NSString *category = [identity attributeStringValueForName:@"category"];
          NSString *type = [identity attributeStringValueForName:@"type"];

          if ([category isEqualToString:@"proxy"] && [type isEqualToString:@"bytestreams"]) {
            [self queryProxyAddressWithJID:iq.from];
          }
        }
      }
  };

  if (dispatch_get_specific(moduleQueueTag))
    block();
  else
    dispatch_async(moduleQueue, block);
}

/**
* This method handles the server's response to the address query sent before.
* If there is no error, we assume that we were sent an address and a port in
* the form of a streamhost and send the streamhosts to the recipient to begin
* the actual connection process.
*
* @see sendStreamHostsAndWaitForConnection
*/
- (void)handleProxyAddressQueryIQ:(XMPPIQ *)iq withInfo:(XMPPBasicTrackingInfo *)info
{
  XMPPLogTrace();

  dispatch_block_t block = ^{
      @autoreleasepool {
        if (!iq) {
          // If we're inside this block, it means that the timeout has been
          // fired and we need to force a failure
          NSString *errMsg = @"Timeout waiting for proxy address discovery response.";
          [self failWithReason:errMsg error:nil];
        }

        NSXMLElement *errorElem = [iq elementForName:@"error"];

        if (errorElem) {
          NSString *errMsg = [errorElem.children componentsJoinedByString:@", "];
          NSError *err = [self localErrorWithMessage:errMsg
                                                code:[errorElem attributeIntValueForName:@"code"]];
          [self failWithReason:@"There was an issue with the proxy address query." error:err];
          return_from_block;
        }

        NSXMLElement *query = [iq elementForName:@"query" xmlns:XMPPBytestreamsNamespace];
        NSXMLElement *streamHost = [query elementForName:@"streamhost"];

        if (!streamHost) {
          [self failWithReason:@"There must be at least one streamhost." error:nil];
          return_from_block;
        }

        // Detach the streamHost object so it can later be added to a query
        [streamHost detach];
        [_streamhosts addObject:streamHost];

        [self sendStreamHostsAndWaitForConnection];
      }
  };

  if (dispatch_get_specific(moduleQueueTag))
    block();
  else
    dispatch_async(moduleQueue, block);
}

/**
* This method handles the server's response after sending the query of
* streamhosts. If there is an error, it alerts the delegate and causes the
* transfer to fail. Otherwise, the connection will proceed and the data will be
* written to the bytestream.
*/
- (void)handleSentStreamhostsQueryIQ:(XMPPIQ *)iq withInfo:(XMPPBasicTrackingInfo *)info
{
  XMPPLogTrace();

  dispatch_block_t block = ^{
      @autoreleasepool {
        NSXMLElement *errorElem = [iq elementForName:@"error"];

        if (errorElem) {
          NSString *errMsg = [errorElem.children componentsJoinedByString:@", "];
          NSError *err = [self localErrorWithMessage:errMsg
                                                code:[errorElem attributeIntValueForName:@"code"]];
          [self failWithReason:@"There was an issue with sending the streamhosts." error:err];
          return_from_block;
        }

        // Check for <streamhost-used/>
        //
        // We're expecting something like:
        //
        // <iq xmlns="jabber:client"
        //     from="tyrael@sanctuary.org/talrashastomb"
        //     to="deckardcain@sanctuary.org/tristram"
        //     type="result"
        //     id="A07A356F-DF15-49BC-92D8-EB3C0357A190">
        //  <query xmlns="http://jabber.org/protocol/bytestreams">
        //    <streamhost-used jid="deckardcain@sanctuary.org/tristram"/>
        //  </query>
        // </iq>

        NSXMLElement *query = iq.childElement;
        NSXMLElement *streamhostUsed = [query elementForName:@"streamhost-used"];

        NSString *jid = [streamhostUsed attributeStringValueForName:@"jid"];
        XMPPLogVerbose(@"%@: streamhost-used received with jid: %@", THIS_FILE, jid);

        if ([jid isEqualToString:xmppStream.myJID.full]) {
          XMPPLogVerbose(@"%@: writing data via direct connection.", THIS_FILE);
          [_outgoingSocket writeData:_outgoingData
                         withTimeout:TIMEOUT_WRITE
                                 tag:SOCKS_TAG_WRITE_DATA];
          return;
        }

        XMPPLogVerbose(@"%@: unable use a direct connection; trying the provided streamhost.",
                       THIS_FILE);

        if (_outgoingSocket) {
          if (_outgoingSocket.isConnected) {
            [_outgoingSocket disconnect];
          }
          _outgoingSocket = nil;
        }

        // We need to get the streamhost which we discovered earlier as a proxy.
        NSXMLElement *proxy;
        for (NSXMLElement *streamhost in _streamhosts) {
          if ([jid isEqualToString:[streamhost attributeStringValueForName:@"jid"]]) {
            proxy = streamhost;
            _proxyJID = [XMPPJID jidWithString:jid];
            break;
          }
        }

        if (_asyncSocket) {
          [_asyncSocket setDelegate:nil];
          [_asyncSocket disconnect];
        }

        if (!_asyncSocket) {
          _asyncSocket = [[GCDAsyncSocket alloc] initWithDelegate:self
                                                    delegateQueue:_outgoingQueue];
        } else {
          [_asyncSocket setDelegate:self];
        }

        NSError *err;
        NSString *proxyHost = [proxy attributeStringValueForName:@"host"];
        uint16_t proxyPort = [proxy attributeUnsignedIntegerValueForName:@"port"];

        if (![_asyncSocket connectToHost:proxyHost onPort:proxyPort error:&err]) {
          [self failWithReason:@"Unable to connect to proxy." error:err];
          return_from_block;
        }

        _transferState = XMPPOFTStateConnectingToProxy;
        // See the GCDAsyncSocket Delegate for the next steps.
      }
  };

  if (dispatch_get_specific(moduleQueueTag))
    block();
  else
    dispatch_async(moduleQueue, block);
}

/**
* This method handles the server's response after sending the <activate/> IQ
* query as described in XEP-0065 Example 24.
*
* If the response is valid (Example 25), the actual transfer of data begins.
*/
- (void)handleSentActivateQueryIQ:(XMPPIQ *)iq withInfo:(XMPPBasicTrackingInfo *)info
{
  XMPPLogTrace();

  dispatch_block_t block = ^{
      @autoreleasepool {
        if (!iq) {
          // If we're inside this block, it means that the timeout has been
          // fired and we need to force a failure
          NSString *errMsg = @"Timeout waiting for sent activate response.";
          [self failWithReason:errMsg error:nil];
        }

        XMPPLogVerbose(@"Receive response to activate. Starting the actual data transfer now...");
        [_asyncSocket writeData:_outgoingData withTimeout:TIMEOUT_WRITE tag:SOCKS_TAG_WRITE_DATA];
      }
  };

  if (dispatch_get_specific(moduleQueueTag))
    block();
  else
    dispatch_async(moduleQueue, block);
}


#pragma mark - Util Methods

- (NSError *)localErrorWithMessage:(NSString *)msg code:(NSInteger)code
{
  NSDictionary *errInfo = @{NSLocalizedDescriptionKey : [msg copy]};
  return [NSError errorWithDomain:XMPPOutgoingFileTransferErrorDomain
                             code:code
                         userInfo:errInfo];
}

- (NSString *)getIPAddress:(BOOL)preferIPv4
{
  NSArray *searchArray;

  if (preferIPv4) {
    searchArray = @[IOS_WIFI @"/" IP_ADDR_IPv4, IOS_WIFI @"/" IP_ADDR_IPv6,
                    IOS_CELLULAR @"/" IP_ADDR_IPv4, IOS_CELLULAR @"/" IP_ADDR_IPv6];
  } else {
    searchArray = @[IOS_WIFI @"/" IP_ADDR_IPv6, IOS_WIFI @"/" IP_ADDR_IPv4,
                    IOS_CELLULAR @"/" IP_ADDR_IPv6, IOS_CELLULAR @"/" IP_ADDR_IPv4];
  }

  NSDictionary *addresses = [self getIPAddresses];

  __block NSString *address;
  [searchArray enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL *stop) {
      address = addresses[key];
      if (address) *stop = YES;
  }];

  return address;
}

- (NSDictionary *)getIPAddresses
{
  NSMutableDictionary *addresses = [NSMutableDictionary dictionaryWithCapacity:8];

  // Retrieve the current interfaces — returns 0 on success
  struct ifaddrs *interfaces;
  if (!getifaddrs(&interfaces)) {
    // Loop through linked list of interfaces
    struct ifaddrs *curr;

    for (curr = interfaces; curr; curr = curr->ifa_next) {
      if (!(curr->ifa_flags & IFF_UP)) {
        continue;
      }

      const struct sockaddr_in *addr = (const struct sockaddr_in *) curr->ifa_addr;
      char addr_buf[MAX(INET_ADDRSTRLEN, INET6_ADDRSTRLEN)];

      if (addr && (addr->sin_family == AF_INET || addr->sin_family == AF_INET6)) {
        NSString *name = [NSString stringWithUTF8String:curr->ifa_name];
        NSString *type;

        if (addr->sin_family == AF_INET) {
          if (inet_ntop(AF_INET, &addr->sin_addr, addr_buf, INET_ADDRSTRLEN)) {
            type = IP_ADDR_IPv4;
          }
        } else {
          const struct sockaddr_in6 *addr6 = (const struct sockaddr_in6 *) curr->ifa_addr;

          if (inet_ntop(AF_INET6, &addr6->sin6_addr, addr_buf, INET6_ADDRSTRLEN)) {
            type = IP_ADDR_IPv6;
          }
        }

        if (type) {
          NSString *key = [NSString stringWithFormat:@"%@/%@", name, type];
          addresses[key] = [NSString stringWithUTF8String:addr_buf];
        }
      }
    }

    freeifaddrs(interfaces);
  }

  return addresses.count ? addresses : nil;
}

/**
* Returns a random port number between 1024 and 49151, since these are the
* values available to use as ports.
*/
+ (uint16_t)getRandomPort
{
  int port = arc4random_uniform(49151);
  return (uint16_t) (port < 1024 ? port + 1024 : port);
}

/**
* This method returns the SHA1 hash as per XEP-0065.
*
* The [address] MUST be SHA1(SID + Initiator JID + Target JID) and the output
* is hexadecimal encoded (not binary).
*
* Because this is an outgoing file transfer, we are always the initiator.
*/
- (NSData *)sha1Hash
{
  NSString *hashMe =
      [NSString stringWithFormat:@"%@%@%@", self.sid, xmppStream.myJID.full, _recipientJID.full];
  NSData *hashRaw = [[hashMe dataUsingEncoding:NSUTF8StringEncoding] xmpp_sha1Digest];
  NSData *hash = [[hashRaw xmpp_hexStringValue] dataUsingEncoding:NSUTF8StringEncoding];

  XMPPLogVerbose(@"%@: hashMe : %@", THIS_FILE, hashMe);
  XMPPLogVerbose(@"%@: hashRaw: %@", THIS_FILE, hashRaw);
  XMPPLogVerbose(@"%@: hash   : %@", THIS_FILE, hash);

  return hash;
}

/**
* This method is called to clean up everything if the transfer fails.
*/
- (void)failWithReason:(NSString *)causeOfFailure error:(NSError *)error
{
  XMPPLogTrace();
  XMPPLogInfo(@"Outgoing file transfer failed because: %@", causeOfFailure);

  if (!error && causeOfFailure) {
    NSDictionary *errInfo = @{NSLocalizedDescriptionKey : causeOfFailure};
    error = [NSError errorWithDomain:XMPPOutgoingFileTransferErrorDomain
                                code:-1
                            userInfo:errInfo];
  }

  [self cleanUp];
  [multicastDelegate xmppOutgoingFileTransfer:self didFailWithError:error];
}

/**
* This method is called to clean up everything if the transfer succeeds.
*/
- (void)transferSuccess
{

  XMPPLogTrace();

  dispatch_block_t block = ^{
      @autoreleasepool {
        _transferState = XMPPOFTStateFinished;
        [multicastDelegate xmppOutgoingFileTransferDidSucceed:self];
        [self cleanUp];
      }
  };

  if (dispatch_get_specific(moduleQueueTag))
    block();
  else
    dispatch_async(moduleQueue, block);
}

/**
* This method is used to reset the system for receiving new files.
*/
- (void)cleanUp
{
  XMPPLogTrace();

  if (_asyncSocket) {
    [_asyncSocket setDelegate:nil];
    [_asyncSocket disconnect];
    _asyncSocket = nil;
  }

  if (_outgoingSocket) {
    [_outgoingSocket setDelegate:nil];
    [_outgoingSocket disconnect];
    _outgoingSocket = nil;
  }

  _streamMethods &= 0;
  _transferState = XMPPOFTStateNone;
  _totalDataSize = 0;
  _outgoingDataBlockSeq = 0;
  _sentDataSize = 0;
  _outgoingDataBase64 = nil;
}


#pragma mark - XMPPStreamDelegate

/**
* Default XMPPStreamDelegate method. We need this to handle the IQ responses.
*/
- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
  NSString *type = iq.type;

  if ([type isEqualToString:@"result"] || [type isEqualToString:@"error"]) {
    return [_idTracker invokeForElement:iq withObject:iq];
  }

  return NO;
}


#pragma mark - GCDAsyncSocketDelegate

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
  XMPPLogVerbose(@"Did accept new socket");
  XMPPLogVerbose(@"connected host: %@", newSocket.connectedHost);
  XMPPLogVerbose(@"connected port: %hu", newSocket.connectedPort);

  _outgoingSocket = newSocket;
  [_outgoingSocket readDataToLength:3 withTimeout:20 tag:SOCKS_TAG_READ_METHOD];
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port
{
  XMPPLogVerbose(@"%@: didConnectToHost:%@ port:%d", THIS_FILE, host, port);

  [self socks5WriteProxyMethod];
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
  XMPPLogVerbose(@"%@: didReadData:%@ withTag:%ld", THIS_FILE, data, tag);

  switch (tag) {
    case SOCKS_TAG_READ_METHOD:
      [self socks5ReadMethod:data];
      break;
    case SOCKS_TAG_READ_REQUEST:
      [self socks5ReadRequest:data];
      break;
    case SOCKS_TAG_READ_DOMAIN:
      [self socks5ReadDomain:data];
      break;
    case SOCKS_TAG_READ_PROXY_METHOD:
      [self socks5ReadProxyMethod:data];
      break;
    case SOCKS_TAG_READ_PROXY_REPLY:
      [self socks5ReadProxyReply:data];
      break;
    default:
      break;
  }
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
  XMPPLogVerbose(@"%@: didWriteDataWithTag:%ld", THIS_FILE, tag);

  switch (tag) {
    case SOCKS_TAG_WRITE_METHOD:
      [_outgoingSocket readDataToLength:4 withTimeout:TIMEOUT_READ tag:SOCKS_TAG_READ_REQUEST];
      break;
    case SOCKS_TAG_WRITE_PROXY_METHOD:
      [_asyncSocket readDataToLength:2 withTimeout:TIMEOUT_READ tag:SOCKS_TAG_READ_PROXY_METHOD];
      break;
    case SOCKS_TAG_WRITE_PROXY_CONNECT:
      [_asyncSocket readDataToLength:5 withTimeout:TIMEOUT_READ tag:SOCKS_TAG_READ_PROXY_REPLY];
      break;
    case SOCKS_TAG_WRITE_DATA:
      [self transferSuccess];
      break;
    default:
      break;
  }
}

- (NSTimeInterval)socket:(GCDAsyncSocket *)sock
shouldTimeoutReadWithTag:(long)tag
                 elapsed:(NSTimeInterval)elapsed
               bytesDone:(NSUInteger)length
{
  XMPPLogVerbose(@"%@: socket shouldTimeoutReadWithTag:%ld elapsed:%f bytesDone:%lu", THIS_FILE, tag, elapsed, (unsigned long)length);

  NSString *reason = [NSString stringWithFormat:@"Read timeout. %lu bytes read.", (unsigned long)length];
  [self failWithReason:reason error:nil];

  return 0;
}

- (NSTimeInterval) socket:(GCDAsyncSocket *)sock
shouldTimeoutWriteWithTag:(long)tag
                  elapsed:(NSTimeInterval)elapsed
                bytesDone:(NSUInteger)length
{
  XMPPLogVerbose(@"%@: socket shouldTimeoutWriteWithTag:%ld elapsed:%f bytesDone:%lu", THIS_FILE,
                 tag, elapsed, (unsigned long) length);

  NSString *reason = [NSString stringWithFormat:@"Write timeout. %lu bytes written.",
                                                (unsigned long) length];
  [self failWithReason:reason error:nil];

  return 0;
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
  XMPPLogVerbose(@"socket did disconnect with error: %@", err);
  if (_transferState != XMPPOFTStateFinished && _transferState != XMPPOFTStateNone) {
    [self failWithReason:@"Socket disconnected before transfer completion." error:err];
  }
}


#pragma mark - SOCKS5

- (void)socks5ReadMethod:(NSData *)incomingData
{
  XMPPLogTrace();

  dispatch_block_t block = ^{
      @autoreleasepool {
        // According to the SOCKS5 protocol (http://tools.ietf.org/html/rfc1928),
        // we facilitate the role of the 'server' in this scenario, meaning that
        // the 'client' has connected to us and written data in the following form:
        //
        //                 +----+----------+----------+
        //                 |VER | NMETHODS | METHODS  |
        //                 +----+----------+----------+
        //                 | 1  |    1     | 1 to 255 |
        //                 +----+----------+----------+
        //
        // The VER field should always be set to 5 (for SOCKS v5).
        // NMETHODS will always be a single byte and since we really only want this
        // to be 1, we're free to ignore it.
        // METHODS can have various values, but if it's set to anything other than
        // 0 (no authentication), we're going to abort the process.
        //
        // We're thus expecting:
        //
        // VER      = 5
        // NMETHODS = 1
        // METHODS  = 0

        UInt8 version = [NSNumber xmpp_extractUInt8FromData:incomingData atOffset:0];
        UInt8 method = [NSNumber xmpp_extractUInt8FromData:incomingData atOffset:2];

        if (version == 5 && method == 0) {

          // At this point, we've determined that no authentication is required and
          // are able to proceed. In order to do so, we need to write data in the
          // following form:
          //
          //                    +----+--------+
          //                    |VER | METHOD |
          //                    +----+--------+
          //                    | 1  |   1    |
          //                    +----+--------+
          //
          // The VER will once again be set to 5, and METHOD will be set to 0.
          //
          // We're sending:
          //
          // VER    = 5
          // METHOD = 0

          void *byteBuf = malloc(2);

          UInt8 ver = 5;
          memcpy(byteBuf, &ver, sizeof(ver));

          UInt8 mtd = 0;
          memcpy(byteBuf + 1, &mtd, sizeof(mtd));

          NSData *responseData = [NSData dataWithBytesNoCopy:byteBuf length:2 freeWhenDone:YES];
          XMPPLogVerbose(@"%@: writing SOCKS5 auth response: %@", THIS_FILE, responseData);

          [_outgoingSocket writeData:responseData
                         withTimeout:TIMEOUT_WRITE
                                 tag:SOCKS_TAG_WRITE_METHOD];
        }
      }
  };

  if (dispatch_get_specific(moduleQueueTag))
    block();
  else
    dispatch_async(moduleQueue, block);
}

- (void)socks5ReadRequest:(NSData *)incomingData
{
  XMPPLogTrace();

  dispatch_block_t block = ^{
      @autoreleasepool {
        //  The SOCKS request is formed as follows:
        //
        //       +----+-----+-------+------+----------+----------+
        //       |VER | CMD |  RSV  | ATYP | DST.ADDR | DST.PORT |
        //       +----+-----+-------+------+----------+----------+
        //       | 1  |  1  | X'00' |  1   | Variable |    2     |
        //       +----+-----+-------+------+----------+----------+
        //
        // We're expecting:
        //
        // VER      = 5
        // CMD      = 1 (connect)
        // RSV      = 0 (reserved; this will always be 0)
        // ATYP     = 1 (IPv4), 3 (domain name), or 4 (IPv6)
        // DST.ADDR (varies based on ATYP)
        // DST.PORT = 0 (according to XEP-0065)
        //
        // At this stage, we've only actually read 4 bytes from the stream, those
        // being VER, CMD, RSV, and ATYP. We need to read ATYP to determine how many
        // more bytes we should read. Scenarios listed below:
        //
        // ATYP = 3 (domain name): Read the next byte which will contain the number
        //                         bytes in the address. Then read that many bytes +
        //                         2 for the port. Since this is the only type of
        //                         ATYP we want to support, any other fails. We'll go
        //                         ahead and read the whole address and port. It
        //                         should always be 40 bytes long (SHA1).

        UInt8 ver = [NSNumber xmpp_extractUInt8FromData:incomingData atOffset:0];
        UInt8 cmd = [NSNumber xmpp_extractUInt8FromData:incomingData atOffset:1];
        UInt8 atyp = [NSNumber xmpp_extractUInt8FromData:incomingData atOffset:3];

        if (ver != 5 || cmd != 1) {
          [self failWithReason:@"Incorrect SOCKS version or command is not 'CONNECT'." error:nil];
          return;
        }

        // Read the length byte + the 40-byte SHA1 + 2-byte address
        NSUInteger length = 43;
        if (atyp == 3) {
          [_outgoingSocket readDataToLength:length
                                withTimeout:TIMEOUT_READ
                                        tag:SOCKS_TAG_READ_DOMAIN];
        } else {
          [self failWithReason:@"ATYP value is invalid." error:nil];
        }
      }
  };

  if (dispatch_get_specific(moduleQueueTag))
    block();
  else
    dispatch_async(moduleQueue, block);
}

- (void)socks5ReadDomain:(NSData *)incomingData
{
  XMPPLogTrace();

  dispatch_block_t block = ^{
      @autoreleasepool {
        NSData *hash = [self sha1Hash];

        // We need to pull the address data out, which starts after the first byte
        // and goes for 40 bytes.
        NSRange addrRange = NSMakeRange(1, 40);
        if (![hash isEqualToData:[incomingData subdataWithRange:addrRange]]) {
          XMPPLogVerbose(@"Addresses don't match. Canceling the SOCKS5 transfer.");
          [self failWithReason:@"Addresses don't match." error:nil];
          return;
        }

        // We need to next pull the port out and verify that it's 0x00, 0x00.
        UInt8 addrPort0 = [NSNumber xmpp_extractUInt8FromData:incomingData atOffset:41];
        UInt8 addrPort1 = [NSNumber xmpp_extractUInt8FromData:incomingData atOffset:41];

        if (addrPort0 || addrPort1) {
          XMPPLogVerbose(@"Port should always be 0x00. Canceling the SOCKS5 transfer.");
          [self failWithReason:@"Port isn't 0x00." error:nil];
          return;
        }

        // If the DST.ADDR and DST.PORT are valid, then we proceed with the process.
        // We send our reply which is described below.
        //
        //          +----+-----+-------+------+----------+----------+
        //          |VER | REP |  RSV  | ATYP | BND.ADDR | BND.PORT |
        //          +----+-----+-------+------+----------+----------+
        //          | 1  |  1  | X'00' |  1   | Variable |    2     |
        //          +----+-----+-------+------+----------+----------+
        //
        // VER = 5 (SOCKS5)
        // REP = 0 (Success)
        // RSV = 0
        // ATYP = 3 (Domain) - NOTE: Since we're using ATYP = 3, we must send the
        //                           length of our host in the very next byte.
        // BND.ADDR = local IP address
        // BND.PORT = 0x00
        //            0x00

        const char *host = [_localIPAddress UTF8String];

        NSUInteger numBytes = 5 + strlen(host) + 2;

        void *byteBuf = malloc(numBytes);

        UInt8 ver = 5;
        memcpy(byteBuf, &ver, sizeof(ver));

        UInt8 rep = 0;
        memcpy(byteBuf + 1, &rep, sizeof(rep));

        UInt8 rsv = 0;
        memcpy(byteBuf + 2, &rsv, sizeof(rsv));

        UInt8 atyp = 3;
        memcpy(byteBuf + 3, &atyp, sizeof(atyp));

        UInt8 hostlen = (UInt8) strlen(host);
        memcpy(byteBuf + 4, &hostlen, sizeof(hostlen));

        memcpy(byteBuf + 5, host, hostlen);

        UInt8 port = 0;
        memcpy(byteBuf + 5 + hostlen, &port, sizeof(port));
        memcpy(byteBuf + 6 + hostlen, &port, sizeof(port));

        NSData
            *responseData = [NSData dataWithBytesNoCopy:byteBuf length:numBytes freeWhenDone:YES];
        XMPPLogVerbose(@"%@: writing SOCKS5 auth response: %@", THIS_FILE, responseData);

        [_outgoingSocket writeData:responseData
                       withTimeout:TIMEOUT_WRITE
                               tag:SOCKS_TAG_WRITE_REPLY];

        _transferState = XMPPOFTStateSOCKSLive;

        // Now we wait for a <streamhost-used/> IQ stanza before sending the data.
      }
  };

  if (dispatch_get_specific(moduleQueueTag))
    block();
  else
    dispatch_async(moduleQueue, block);
}

- (void)socks5WriteProxyMethod
{
  XMPPLogTrace();

  dispatch_block_t block = ^{
      @autoreleasepool {
        // We will attempt anonymous authentication with the proxy. The request is
        // the same that we would read if this were a direct connection. The only
        // difference is this time we initiate the request as a client rather than
        // being a the 'server.'
        //
        //                 +----+----------+----------+
        //                 |VER | NMETHODS | METHODS  |
        //                 +----+----------+----------+
        //                 | 1  |    1     | 1 to 255 |
        //                 +----+----------+----------+
        //
        // We're sending:
        //
        // VER      = 5 (SOCKS5)
        // NMETHODS = 1 (number of methods)
        // METHODS  = 0 (no authentication)

        void *byteBuf = malloc(3);

        UInt8 ver = 5;
        memcpy(byteBuf, &ver, sizeof(ver));

        UInt8 nmethods = 1;
        memcpy(byteBuf + 1, &nmethods, sizeof(nmethods));

        UInt8 methods = 0;
        memcpy(byteBuf + 2, &methods, sizeof(methods));

        NSData *data = [NSData dataWithBytesNoCopy:byteBuf length:3 freeWhenDone:YES];
        [_asyncSocket writeData:data withTimeout:TIMEOUT_WRITE tag:SOCKS_TAG_WRITE_PROXY_METHOD];
      }
  };

  if (dispatch_get_specific(moduleQueueTag))
    block();
  else
    dispatch_async(moduleQueue, block);
}

- (void)socks5ReadProxyMethod:(NSData *)incomingData
{
  XMPPLogTrace();

  dispatch_block_t block = ^{
      @autoreleasepool {
        // We've sent a request to connect with no authentication. This data contains
        // the proxy server's response to our request.
        //
        //                    +----+--------+
        //                    |VER | METHOD |
        //                    +----+--------+
        //                    | 1  |   1    |
        //                    +----+--------+
        //
        // We're expecting:
        //
        // VER    = 5 (SOCKS5)
        // METHOD = 0 (no authentication)

        UInt8 version = [NSNumber xmpp_extractUInt8FromData:incomingData atOffset:0];
        UInt8 method = [NSNumber xmpp_extractUInt8FromData:incomingData atOffset:1];

        if (version != 5 || method) {
          [self failWithReason:@"Proxy doesn't allow anonymous authentication." error:nil];
          return;
        }

        NSData *hash = [self sha1Hash];

        //  The SOCKS request is formed as follows:
        //
        //       +----+-----+-------+------+----------+----------+
        //       |VER | CMD |  RSV  | ATYP | DST.ADDR | DST.PORT |
        //       +----+-----+-------+------+----------+----------+
        //       | 1  |  1  | X'00' |  1   | Variable |    2     |
        //       +----+-----+-------+------+----------+----------+
        //
        // We're sending:
        //
        // VER      = 5
        // CMD      = 1 (connect)
        // RSV      = 0 (reserved; this will always be 0)
        // ATYP     = 3 (domain name)
        // DST.ADDR (varies based on ATYP)
        // DST.PORT = 0 (according to XEP-0065)
        //
        // Immediately after ATYP, we need to send the length of our address. Because
        // SHA1 is always 40 bytes, we simply send this value. After it, we append
        // the actual hash and then the port.

        void *byteBuf = malloc(5 + 40 + 2);

        UInt8 ver = 5;
        memcpy(byteBuf, &ver, sizeof(ver));

        UInt8 cmd = 1;
        memcpy(byteBuf + 1, &cmd, sizeof(cmd));

        UInt8 rsv = 0;
        memcpy(byteBuf + 2, &rsv, sizeof(rsv));

        UInt8 atyp = 3;
        memcpy(byteBuf + 3, &atyp, sizeof(atyp));

        UInt8 hashlen = (UInt8) hash.length;
        memcpy(byteBuf + 4, &hashlen, sizeof(hashlen));

        memcpy(byteBuf + 5, hash.bytes, hashlen);

        UInt8 port = 0;
        memcpy(byteBuf + 5 + hashlen, &port, sizeof(port));
        memcpy(byteBuf + 6 + hashlen, &port, sizeof(port));

        NSData *data = [NSData dataWithBytesNoCopy:byteBuf length:47 freeWhenDone:YES];
        [_asyncSocket writeData:data withTimeout:TIMEOUT_WRITE tag:SOCKS_TAG_WRITE_PROXY_CONNECT];

        XMPPLogVerbose(@"%@: writing connect request: %@", THIS_FILE, data);
      }
  };

  if (dispatch_get_specific(moduleQueueTag))
    block();
  else
    dispatch_async(moduleQueue, block);
}

- (void)socks5ReadProxyReply:(NSData *)incomingData
{
  XMPPLogTrace();

  dispatch_block_t block = ^{
      @autoreleasepool {
        // The server will reply to our connect command with the following:
        //
        //          +----+-----+-------+------+----------+----------+
        //          |VER | REP |  RSV  | ATYP | BND.ADDR | BND.PORT |
        //          +----+-----+-------+------+----------+----------+
        //          | 1  |  1  | X'00' |  1   | Variable |    2     |
        //          +----+-----+-------+------+----------+----------+
        //
        // VER = 5 (SOCKS5)
        // REP = 0 (Success)
        // RSV = 0
        // ATYP = 3 (Domain) - NOTE: Since we're using ATYP = 3, we must check the
        //                           length of the server's host in the next byte.

        UInt8 ver = [NSNumber xmpp_extractUInt8FromData:incomingData atOffset:0];
        UInt8 rep = [NSNumber xmpp_extractUInt8FromData:incomingData atOffset:1];
        UInt8 atyp = [NSNumber xmpp_extractUInt8FromData:incomingData atOffset:3];
        UInt8 hostlen = [NSNumber xmpp_extractUInt8FromData:incomingData atOffset:4];

        if (ver != 5 || rep || atyp != 3) {
          [self failWithReason:@"Invalid VER, REP, or ATYP." error:nil];
          return;
        }

        // Read those bytes off into oblivion...
        [_asyncSocket readDataToLength:hostlen + 2 withTimeout:TIMEOUT_READ tag:-1];

        // According to XEP-0065 Example 23, we don't need to validate the
        // address we were sent (at least that is how I interpret it), so we
        // can just go ahead and send the <activate/> IQ query and start
        // sending the data once we receive our response.

        NSXMLElement *activate = [NSXMLElement elementWithName:@"activate"
                                                   stringValue:_recipientJID.full];

        NSXMLElement *query = [NSXMLElement elementWithName:@"query"
                                                      xmlns:@"http://jabber.org/protocol/bytestreams"];
        [query addAttributeWithName:@"sid" stringValue:self.sid];
        [query addChild:activate];

        XMPPIQ *iq = [XMPPIQ iqWithType:@"set"
                                     to:_proxyJID
                              elementID:[xmppStream generateUUID]
                                  child:query];

        [_idTracker addElement:iq
                        target:self
                      selector:@selector(handleSentActivateQueryIQ:withInfo:)
                       timeout:OUTGOING_DEFAULT_TIMEOUT];

        [xmppStream sendElement:iq];
      }
  };

  if (dispatch_get_specific(moduleQueueTag))
    block();
  else
    dispatch_async(moduleQueue, block);
}

@end
