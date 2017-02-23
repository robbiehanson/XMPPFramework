//
// Created by Jonathon Staff on 10/21/14.
// Copyright (c) 2014 nplexity, LLC. All rights reserved.
//

#if !__has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

#import "XMPPIncomingFileTransfer.h"
#import "XMPPConstants.h"
#import "XMPPLogging.h"
#import "NSNumber+XMPP.h"
#import "NSData+XMPP.h"

#if DEBUG
static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN; // XMPP_LOG_LEVEL_VERBOSE | XMPP_LOG_FLAG_TRACE;
#else
    static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

/**
* Tags for _asyncSocket handling.
*/
#define SOCKS_TAG_WRITE_METHOD 101
#define SOCKS_TAG_READ_METHOD 102
#define SOCKS_TAG_WRITE_CONNECT 103
#define SOCKS_TAG_READ_REPLY 104
#define SOCKS_TAG_READ_ADDRESS 105
#define SOCKS_TAG_READ_DATA 106

#define TIMEOUT_WRITE -1
#define TIMEOUT_READ 5.0

// XMPP Incoming File Transfer State
typedef NS_ENUM(int, XMPPIFTState) {
  XMPPIFTStateNone,
  XMPPIFTStateWaitingForSIOffer,
  XMPPIFTStateWaitingForStreamhosts,
  XMPPIFTStateConnectingToStreamhosts,
  XMPPIFTStateConnected,
  XMPPIFTStateWaitingForIBBOpen,
  XMPPIFTStateWaitingForIBBData
};

NSString *const XMPPIncomingFileTransferErrorDomain = @"XMPPIncomingFileTransferErrorDomain";

@interface XMPPIncomingFileTransfer () {
  XMPPIFTState _transferState;

  XMPPJID *_senderJID;

  NSString *_streamhostsQueryId;
  NSString *_streamhostUsed;

  NSMutableData *_receivedData;
  NSString *_receivedFileName;
  NSUInteger _totalDataSize;
  NSUInteger _receivedDataSize;

  dispatch_source_t _ibbTimer;
}

@end

@implementation XMPPIncomingFileTransfer


#pragma mark - Lifecycle

- (instancetype)initWithDispatchQueue:(dispatch_queue_t)queue
{
  self = [super initWithDispatchQueue:queue];
  if (self) {
    _transferState = XMPPIFTStateNone;
  }
  return self;
}

/**
* Standard deconstructor.
*/
- (void)dealloc
{
  XMPPLogTrace();

  if (_transferState != XMPPIFTStateNone) {
    XMPPLogWarn(@"%@: Deallocating prior to completion or cancellation.", THIS_FILE);
  }

  if (_ibbTimer)
    dispatch_source_cancel(_ibbTimer);
#if !OS_OBJECT_USE_OBJC
  dispatch_release(_ibbTimer);
  #endif
  _ibbTimer = NULL;

  if (_asyncSocket.delegate == self) {
    [_asyncSocket setDelegate:nil delegateQueue:NULL];
    [_asyncSocket disconnect];
  }
}


#pragma mark - Public Methods

/**
* Public facing method for accepting a SI offer. If autoAcceptFileTransfers is
* set to YES, this method will do nothing, since the internal method is invoked
* automatically.
*
* @see sendSIOfferAcceptance:
*/
- (void)acceptSIOffer:(XMPPIQ *)offer
{
  XMPPLogTrace();

  if (!_autoAcceptFileTransfers) {
    [self sendSIOfferAcceptance:offer];
  }
}


#pragma mark - Private Methods

/**
* This method will send the device's identity in response to a `disco#info`
* query. In our case, we will send something close the following:
*
* <iq type="result"
*     id="purplea2da8fc9"
*     from="mephisto@sanctuary.org/kurast"
*     to="baal@sanctuary.org/worldstonechamber">
*   <query xmlns="http://jabber.org/protocol/disco#info">
*     <identity category="client" type="phone"/>
*       <feature var="http://jabber.org/protocol/si"/>
*       <feature var="http://jabber.org/protocol/si/profile/file-transfer"/>
*       <feature var="http://jabber.org/protocol/bytestreams"/>
*       <feature var="http://jabber.org/protocol/ibb"/>
*   </query>
* </iq>
*
* This tells the requester who they're dealing with and which transfer types
* we support. If there's a better way than hard-coding these values, I'm open
* to suggestions.
*/
- (void)sendIdentity:(XMPPIQ *)request
{
  XMPPLogTrace();

  dispatch_block_t block = ^{
      @autoreleasepool {
        XMPPIQ *iq = [XMPPIQ iqWithType:@"result"
                                     to:request.from
                              elementID:request.elementID];
        [iq addAttributeWithName:@"from" stringValue:xmppStream.myJID.full];

        NSXMLElement
            *query = [NSXMLElement elementWithName:@"query" xmlns:XMPPDiscoInfoNamespace];

        NSXMLElement *identity = [NSXMLElement elementWithName:@"identity"];
        [identity addAttributeWithName:@"category" stringValue:@"client"];
        [identity addAttributeWithName:@"type" stringValue:@"ios-osx"];
        [query addChild:identity];

        NSXMLElement *feature = [NSXMLElement elementWithName:@"feature"];
        [feature addAttributeWithName:@"var" stringValue:XMPPSINamespace];
        [query addChild:feature];

        NSXMLElement *feature1 = [NSXMLElement elementWithName:@"feature"];
        [feature1 addAttributeWithName:@"var" stringValue:XMPPSIProfileFileTransferNamespace];
        [query addChild:feature1];

        if (!self.disableSOCKS5) {
          NSXMLElement *feature2 = [NSXMLElement elementWithName:@"feature"];
          [feature2 addAttributeWithName:@"var" stringValue:XMPPBytestreamsNamespace];
          [query addChild:feature2];
        }

        if (!self.disableIBB) {
          NSXMLElement *feature3 = [NSXMLElement elementWithName:@"feature"];
          [feature3 addAttributeWithName:@"var" stringValue:XMPPIBBNamespace];
          [query addChild:feature3];
        }

        [iq addChild:query];
        [xmppStream sendElement:iq];
      }
  };

  if (dispatch_get_specific(moduleQueueTag))
    block();
  else
    dispatch_async(moduleQueue, block);
}

/**
* This method will send an IQ stanza accepting the SI offer. We need to choose
* which 'stream-method' we prefer to use. For now, we will be using IBB as the
* 'stream-method', but SOCKS5 is preferable.
*
* Take a look at XEP-0096 Examples 2 and 4 for more details.
*/
- (void)sendSIOfferAcceptance:(XMPPIQ *)offer
{
  XMPPLogTrace();

  dispatch_block_t block = ^{
      @autoreleasepool {
        // Store the sender's JID
        _senderJID = offer.from;

        // Store the sid for later use
        NSXMLElement *inSi = offer.childElement;
        self.sid = [inSi attributeStringValueForName:@"id"];

        // Store the size of the incoming data for later use
        NSXMLElement *inFile = [inSi elementForName:@"file"];
        _totalDataSize = [inFile attributeUnsignedIntegerValueForName:@"size"];

        // Store the name of the file for later use
        _receivedFileName = [inFile attributeStringValueForName:@"name"];

        // Outgoing
        XMPPIQ *iq = [XMPPIQ iqWithType:@"result"
                                     to:offer.from
                              elementID:offer.elementID];


        NSXMLElement *si = [NSXMLElement elementWithName:@"si" xmlns:XMPPSINamespace];

        NSXMLElement *feature = [NSXMLElement elementWithName:@"feature"
                                                        xmlns:XMPPFeatureNegNamespace];

        NSXMLElement *x = [NSXMLElement elementWithName:@"x" xmlns:@"jabber:x:data"];
        [x addAttributeWithName:@"type" stringValue:@"submit"];

        NSXMLElement *field = [NSXMLElement elementWithName:@"field"];
        [field addAttributeWithName:@"var" stringValue:@"stream-method"];

        NSXMLElement *value = [NSXMLElement elementWithName:@"value"];

        // Prefer SOCKS5 if it's not disabled.
        if (!self.disableSOCKS5) {
          [value setStringValue:XMPPBytestreamsNamespace];
          _transferState = XMPPIFTStateWaitingForStreamhosts;
        } else {
          [value setStringValue:XMPPIBBNamespace];
          _transferState = XMPPIFTStateWaitingForIBBOpen;
        }

        [field addChild:value];
        [x addChild:field];
        [feature addChild:x];
        [si addChild:feature];
        [iq addChild:si];

        [xmppStream sendElement:iq];
      }
  };

  if (dispatch_get_specific(moduleQueueTag))
    block();
  else
    dispatch_async(moduleQueue, block);
}


#pragma mark - IBB Methods

/**
* This method will send an IQ stanza accepting the IBB request. See XEP-0047
* Example 2 for more details.
*/
- (void)sendIBBAcceptance:(XMPPIQ *)request
{
  XMPPLogTrace();

  dispatch_block_t block = ^{
      @autoreleasepool {
        XMPPIQ *iq = [XMPPIQ iqWithType:@"result"
                                     to:request.from
                              elementID:request.elementID];
        [xmppStream sendElement:iq];

        // Prepare to receive data
        _receivedData = [NSMutableData new];
      }
  };

  if (dispatch_get_specific(moduleQueueTag))
    block();
  else
    dispatch_async(moduleQueue, block);
}

/**
* This method is responsible for reading the incoming data from the IQ stanza
* and writing it to the member variable '_receivedData'. After successfully
* reading the data, a response (XEP-0047 Example 7) will be sent back to the
* sender.
*/
- (void)processReceivedIBBDataIQ:(XMPPIQ *)received
{
  XMPPLogTrace();

  dispatch_block_t block = ^{
      @autoreleasepool {
        // Handle the scenario that the transfer is cancelled.
        [self resetIBBTimer:20];

        // Handle incoming data
        NSXMLElement *dataElem = received.childElement;
        NSData
            *temp = [[NSData alloc] initWithBase64EncodedString:dataElem.stringValue options:0];
        [_receivedData appendData:temp];

        // According the base64 encoding, it takes up 4/3 n bytes of space, so
        // we need to find the size of the data before base64.
        _receivedDataSize += (3 * dataElem.stringValue.length) / 4;

        XMPPLogVerbose(@"Downloaded %lu/%lu bytes in IBB transfer.",
                       (unsigned long) _receivedDataSize, (unsigned long) _totalDataSize);

        if (_receivedDataSize < _totalDataSize) {
          // Send ack response
          XMPPIQ *iq = [XMPPIQ iqWithType:@"result"
                                       to:received.from
                                elementID:received.elementID];
          [xmppStream sendElement:iq];
        } else {
          // We're finished!
          XMPPLogInfo(@"Finished downloading IBB data.");
          [self transferSuccess];
        }
      }
  };

  if (dispatch_get_specific(moduleQueueTag))
    block();
  else
    dispatch_async(moduleQueue, block);
}


#pragma mark - Util Methods

/**
* This method determines whether or not the IQ stanza is a `disco#info`
* request. Should be in the following form:
*
* <iq xmlns="jabber:client"
*     from="baal@sanctuary.org/worldstonechamber"
*     to="mephisto@sanctuary.org/kurast"
*     type="get"
*     id="purplea2da8fc9">
*   <query xmlns="http://jabber.org/protocol/disco#info"/>
* </iq>
*/
- (BOOL)isDiscoInfoIQ:(XMPPIQ *)iq
{
  if (!iq) return NO;
  NSXMLElement *query = iq.childElement;
  return query != nil && [query.xmlns isEqualToString:XMPPDiscoInfoNamespace];
}

/**
* This method determines whether or not the the IQ stanza is a Stream
* Initiation Offer (XEP-0096 Examples 1 and 3).
*/
- (BOOL)isSIOfferIQ:(XMPPIQ *)iq
{
  if (!iq) return NO;
  if (![iq.type isEqualToString:@"set"]) return NO;

  NSXMLElement *si = iq.childElement;
  if (!si || ![si.xmlns isEqualToString:XMPPSINamespace]) return NO;

  NSXMLElement *file = (NSXMLElement *) [si childAtIndex:0];
  if (!file || ![file.xmlns isEqualToString:XMPPSIProfileFileTransferNamespace]) return NO;

  NSXMLElement *feature = (NSXMLElement *) [si childAtIndex:1];
  return !(!feature || ![feature.xmlns isEqualToString:XMPPFeatureNegNamespace]);

  // Maybe there should be further verification, but I think this should be
  // plenty...
}

/**
* This method determines whether or not the IQ stanza is an IBB session request
* (XEP-0047 Example 1).
*/
- (BOOL)isIBBOpenRequestIQ:(XMPPIQ *)iq
{
  if (!iq) return NO;
  if (![iq.type isEqualToString:@"set"]) return NO;

  NSXMLElement *open = iq.childElement;
  return !(!open || ![open.xmlns isEqualToString:XMPPIBBNamespace]);
}

/**
* This method determines whether or not the IQ stanza is an IBB data stanza
* (XEP-0047 Example 6).
*/
- (BOOL)isIBBDataIQ:(XMPPIQ *)iq
{
  if (!iq) return NO;
  if (![iq.type isEqualToString:@"set"]) return NO;

  NSXMLElement *data = iq.childElement;
  return !(!data || ![data.xmlns isEqualToString:XMPPIBBNamespace]);
}

/**
* This method determines whether or not the IQ stanza contains a list of
* streamhosts as shown in XEP-0065 Example 12.
*/
- (BOOL)isStreamhostsListIQ:(XMPPIQ *)iq
{
  if (!iq) return NO;
  if (![iq.type isEqualToString:@"set"]) return NO;

  NSXMLElement *query = iq.childElement;
  if (!query || ![[query attributeStringValueForName:@"sid"] isEqualToString:self.sid]) return NO;

  return [query elementsForName:@"streamhost"].count > 0;
}

/**
* This method returns the SHA1 hash as per XEP-0065.
*
* The [address] MUST be SHA1(SID + Initiator JID + Target JID) and the output
* is hexadecimal encoded (not binary).
*
* Because this is an incoming file transfer, we are always the target.
*/
- (NSData *)sha1Hash
{
  NSString *hashMe =
      [NSString stringWithFormat:@"%@%@%@", self.sid, _senderJID.full, xmppStream.myJID.full];
  NSData *hashRaw = [[hashMe dataUsingEncoding:NSUTF8StringEncoding] xmpp_sha1Digest];
  NSData *hash = [[hashRaw xmpp_hexStringValue] dataUsingEncoding:NSUTF8StringEncoding];

  XMPPLogVerbose(@"%@: hashMe : %@", THIS_FILE, hashMe);
  XMPPLogVerbose(@"%@: hashRaw: %@", THIS_FILE, hashRaw);
  XMPPLogVerbose(@"%@: hash   : %@", THIS_FILE, hash);

  return hash;
}

/**
* This method is called to clean up everything when the transfer fails.
*/
- (void)failWithReason:(NSString *)causeOfFailure
                 error:
                     (NSError *)error
{
  XMPPLogTrace();
  XMPPLogInfo(@"Incoming file transfer failed because: %@", causeOfFailure);

  if (!error && causeOfFailure) {
    NSDictionary *errInfo = @{NSLocalizedDescriptionKey : causeOfFailure};
    error = [NSError errorWithDomain:XMPPIncomingFileTransferErrorDomain
                                code:-1
                            userInfo:errInfo];
  }

  _transferState = XMPPIFTStateNone;
  [multicastDelegate xmppIncomingFileTransfer:self didFailWithError:error];
}

/**
* This method is called when the transfer is successfully completed. It
* handles resetting variables for another transfer and alerts the delegate of
* the transfer completion.
*/
- (void)transferSuccess
{
  XMPPLogTrace();

  dispatch_block_t block = ^{
      @autoreleasepool {
        [self cancelIBBTimer];

        [multicastDelegate xmppIncomingFileTransfer:self
                                 didSucceedWithData:_receivedData
                                              named:_receivedFileName];
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

  _streamMethods &= 0;
  _transferState = XMPPIFTStateNone;
  _senderJID = nil;
  _streamhostsQueryId = nil;
  _streamhostUsed = nil;
  _receivedData = nil;
  _receivedFileName = nil;
  _totalDataSize = 0;
  _receivedDataSize = 0;
}


#pragma mark - Timeouts

/**
* Resets the IBB timer that will cause the transfer to formally fail if an IBB
* data IQ stanza isn't received within the timeout.
*/
- (void)resetIBBTimer:(NSTimeInterval)timeout
{
  NSAssert(dispatch_get_specific(moduleQueueTag), @"Invoked on incorrect queue.");

  if (_ibbTimer == NULL) {
    _ibbTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, moduleQueue);

    dispatch_time_t tt = dispatch_time(DISPATCH_TIME_NOW, timeout * NSEC_PER_SEC);

    dispatch_source_set_timer(_ibbTimer, tt, DISPATCH_TIME_FOREVER, 1);
    dispatch_resume(_ibbTimer);
  } else {
    dispatch_time_t tt = dispatch_time(DISPATCH_TIME_NOW, timeout * NSEC_PER_SEC);
    dispatch_source_set_timer(_ibbTimer, tt, DISPATCH_TIME_FOREVER, 1);
  }

  dispatch_source_set_event_handler(_ibbTimer, ^{
      @autoreleasepool {
        NSString *errMsg = @"The IBB transfer timed out. It's likely that the sender canceled the"
            @" transfer or has gone offline.";
        [self failWithReason:errMsg error:nil];
      }
  });
}

- (void)cancelIBBTimer
{
  NSAssert(dispatch_get_specific(moduleQueueTag), @"Invoked on incorrect queue.");

  if (_ibbTimer) {
    dispatch_source_cancel(_ibbTimer);
#if !OS_OBJECT_USE_OBJC
    dispatch_release(_ibbTimer);
    #endif
    _ibbTimer = NULL;
  }
}


#pragma mark - XMPPStreamDelegate

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
  if (_transferState == XMPPIFTStateNone && [self isDiscoInfoIQ:iq]) {
    [self sendIdentity:iq];
    _transferState = XMPPIFTStateWaitingForSIOffer;
    return YES;
  }

  if ((_transferState == XMPPIFTStateNone || _transferState == XMPPIFTStateWaitingForSIOffer)
      && [self isSIOfferIQ:iq]) {
    // Alert the delegate that we've received a stream initiation offer
    [multicastDelegate xmppIncomingFileTransfer:self didReceiveSIOffer:iq];

    if (_autoAcceptFileTransfers) {
      [self sendSIOfferAcceptance:iq];
    }

    return YES;
  }

  if (_transferState == XMPPIFTStateWaitingForStreamhosts && [self isStreamhostsListIQ:iq]) {
    [self attemptStreamhostsConnection:iq];
    return YES;
  }

  if (_transferState == XMPPIFTStateWaitingForIBBOpen && [self isIBBOpenRequestIQ:iq]) {
    [self sendIBBAcceptance:iq];
    _transferState = XMPPIFTStateWaitingForIBBData;

    // Handle the scenario that the transfer is cancelled.
    [self resetIBBTimer:20];
    return YES;
  }

  if (_transferState == XMPPIFTStateWaitingForIBBData && [self isIBBDataIQ:iq]) {
    [self processReceivedIBBDataIQ:iq];
  }

  return iq != nil;
}


#pragma mark - GCDAsyncSocketDelegate

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port
{
  XMPPLogVerbose(@"%@: didConnectToHost:%@ port:%d", THIS_FILE, host, port);

  [self socks5WriteMethod];
  _transferState = XMPPIFTStateConnected;
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
  XMPPLogVerbose(@"%@: didReadData:%@ withTag:%ld", THIS_FILE, data, tag);

  switch (tag) {
    case SOCKS_TAG_READ_METHOD:
      [self socks5ReadMethod:data];
      break;
    case SOCKS_TAG_READ_REPLY:
      [self socks5ReadReply:data];
    case SOCKS_TAG_READ_ADDRESS:
      [_asyncSocket readDataToLength:_totalDataSize
                         withTimeout:TIMEOUT_READ
                                 tag:SOCKS_TAG_READ_DATA];
      break;
    case SOCKS_TAG_READ_DATA:
      // Success!
      _receivedData = [data mutableCopy];
      [self transferSuccess];
    default:
      break;
  }
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
  XMPPLogVerbose(@"%@: didWriteDataWithTag:%ld", THIS_FILE, tag);

  switch (tag) {
    case SOCKS_TAG_WRITE_METHOD:
      [_asyncSocket readDataToLength:2 withTimeout:TIMEOUT_READ tag:SOCKS_TAG_READ_METHOD];
      break;
    case SOCKS_TAG_WRITE_CONNECT:
      [_asyncSocket readDataToLength:5 withTimeout:TIMEOUT_READ
                                 tag:SOCKS_TAG_READ_REPLY];
    default:
      break;
  }
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
  XMPPLogTrace();

  if (_transferState == XMPPIFTStateConnected) {
    [self failWithReason:@"Socket disconnected before transfer complete." error:nil];
  }
}


#pragma mark - SOCKS5

/**
* This method attempts a connection to each of the streamhosts provided until
* either a connection is established or there are no more streamhosts. In the
* latter case, an error stanza is sent to the sender.
*
* @see socket:didConnectToHost:port:
*/
- (void)attemptStreamhostsConnection:(XMPPIQ *)iq
{
  XMPPLogTrace();

  dispatch_block_t block = ^{
      @autoreleasepool {
        _streamhostsQueryId = iq.elementID;
        _transferState = XMPPIFTStateConnectingToStreamhosts;
        _asyncSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:moduleQueue];

        // Since we've already validated our IQ stanza, we can just pull the data
        NSArray *streamhosts = [iq.childElement elementsForName:@"streamhost"];

        for (NSXMLElement *streamhost in streamhosts) {
          NSString *host = [streamhost attributeStringValueForName:@"host"];
          uint16_t port = [streamhost attributeUInt32ValueForName:@"port"];

          NSError *err;
          if (![_asyncSocket connectToHost:host onPort:port error:&err]) {
            XMPPLogVerbose(@"%@: Unable to host:%@ port:%d error:%@", THIS_FILE, host, port, err);
            continue;
          }

          // If we make it this far, we've successfully connected to one of the hosts.
          _streamhostUsed = [streamhost attributeStringValueForName:@"jid"];

          return;
        }

        // If we reach this, we weren't able to connect to any of the streamhosts.
        // We'll send an error to the sender to let them know, and then we'll alert
        // the delegate of the failure.
        //
        // XEP-0065 Example 13.
        //
        //  <iq from='mephisto@sanctuary.org/kurast'
        //      id='hu3vax16'
        //      to='baal@sanctuary.org/worldstonechamber'
        //      type='error'>
        //    <error type='modify'>
        //      <not-acceptable xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/>
        //    </error>
        //  </iq>

        XMPPIQ *errorIq = [XMPPIQ iqWithType:@"error" to:iq.from elementID:iq.elementID];

        NSXMLElement *errorElem = [NSXMLElement elementWithName:@"error"];
        [errorElem addAttributeWithName:@"type" stringValue:@"modify"];

        NSXMLElement *notAcceptable = [NSXMLElement elementWithName:@"not-acceptable"
                                                              xmlns:@"urn:ietf:params:xml:ns:xmpp-stanzas"];
        [errorElem addChild:notAcceptable];
        [errorIq addChild:errorElem];

        [xmppStream sendElement:errorIq];

        NSString *errMsg = @"Unable to connect to any of the provided streamhosts.";
        [self failWithReason:errMsg error:nil];
      }
  };

  if (dispatch_get_specific(moduleQueueTag))
    block();
  else
    dispatch_async(moduleQueue, block);
}

- (void)socks5WriteMethod
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
        [_asyncSocket writeData:data withTimeout:TIMEOUT_WRITE tag:SOCKS_TAG_WRITE_METHOD];
      }
  };

  if (dispatch_get_specific(moduleQueueTag))
    block();
  else
    dispatch_async(moduleQueue, block);
}

- (void)socks5ReadMethod:(NSData *)incomingData
{
  XMPPLogTrace();

  dispatch_block_t block = ^{
      @autoreleasepool {
        // We've sent a request to connect with no authentication. This is the
        // response:
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
        [_asyncSocket writeData:data withTimeout:TIMEOUT_WRITE tag:SOCKS_TAG_WRITE_CONNECT];

        XMPPLogVerbose(@"%@: writing connect request: %@", THIS_FILE, data);
      }
  };

  if (dispatch_get_specific(moduleQueueTag))
    block();
  else
    dispatch_async(moduleQueue, block);
}

- (void)socks5ReadReply:(NSData *)incomingData
{
  XMPPLogTrace();

  dispatch_block_t block = ^{
      @autoreleasepool {
        // The server/sender will reply to our connect command with the following:
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

        // According to XEP-0065 Example 23, we don't need to validate the
        // address we were sent (at least that is how I interpret it), so we
        // just read the next 42 bytes (hostlen + portlen) so there's no
        // conflict when reading the data and then send <streamhost-used/> to
        // the file transfer initiator. Note that the sid must be included.
        //
        // XEP-0065 Example 17:
        //
        //  <iq from='mephisto@sanctuary.org/kurast'
        //      id='hu3vax16'
        //      to='baal@sanctuary.org/worldstonechamber'
        //      type='result'>
        //    <query xmlns='http://jabber.org/protocol/bytestreams'
        //           sid='vxf9n471bn46'>
        //      <streamhost-used jid='baal@sanctuary.org/worldstonechamber'/>
        //    </query>
        //  </iq>

        XMPPIQ *iq = [XMPPIQ iqWithType:@"result" to:_senderJID elementID:_streamhostsQueryId];

        NSXMLElement *query = [NSXMLElement elementWithName:@"query"
                                                      xmlns:XMPPBytestreamsNamespace];
        [query addAttributeWithName:@"sid" stringValue:self.sid];

        NSXMLElement *streamhostUsed = [NSXMLElement elementWithName:@"streamhost-used"];
        [streamhostUsed addAttributeWithName:@"jid"
                                 stringValue:_streamhostUsed];

        [query addChild:streamhostUsed];
        [iq addChild:query];

        [xmppStream sendElement:iq];

        // We're basically piping these to dev/null because we don't care.
        // However, we need to tag this read so we can start to read the actual
        // data once this read is finished.
        [_asyncSocket readDataToLength:hostlen + 2
                           withTimeout:TIMEOUT_READ
                                   tag:SOCKS_TAG_READ_ADDRESS];
      }
  };

  if (dispatch_get_specific(moduleQueueTag))
    block();
  else
    dispatch_async(moduleQueue, block);
}

@end
