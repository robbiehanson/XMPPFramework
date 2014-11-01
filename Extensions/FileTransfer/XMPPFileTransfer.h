//
// Created by Jonathon Staff on 10/21/14.
// Copyright (c) 2014 nplexity, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XMPP.h"
#import "XMPPModule.h"
#import "TURNSocket.h"
#import "GCDAsyncSocket.h"

@class XMPPIDTracker;

typedef NS_OPTIONS(uint8_t, XMPPFileTransferStreamMethod) {
  XMPPFileTransferStreamMethodBytestreams = 1 << 0, // If set, SOCKS5 connections allowed
  XMPPFileTransferStreamMethodIBB         = 1 << 1, // If set, IBB connections allowed
//  XMPPFileTransferStreamMethodJingle      = 1 << 2  // If set, Jingle connections allowed
  // Note that Jingle is not yet implemented
};

/**
* This class defines common elements of the file transfer process that apply to
* both outgoing and incoming transfers.
*
* You'll find more detailed documentation in each of the implementation files.
*
* By default, the stream-method priority is as follows:
*
* 1. SOCKS5 Direct Connection (http://xmpp.org/extensions/xep-0065.html#direct)
* 2. SOCKS5 Mediated (http://xmpp.org/extensions/xep-0065.html#mediated)
* 3. IBB (http://xmpp.org/extensions/xep-0047.html)
*/
@interface XMPPFileTransfer : XMPPModule <GCDAsyncSocketDelegate> {
  XMPPFileTransferStreamMethod _streamMethods;
  XMPPIDTracker *_idTracker;
  GCDAsyncSocket *_asyncSocket;
  NSMutableArray *_streamhosts;
}

/**
* The streamID ("sid") for the file transfer.
*/
@property (nonatomic, copy) NSString *sid;

/**
* Use this to disable file transfers via direct connection.
*
* If set to YES, SOCKS5 transfers will only take place if there is a proxy that
* works. If set to NO, SOCKS5 transfers will attempt a direct connection first
* and fall back to a proxy if the direct connection doesn't work.
*
* The default value is NO.
*/
@property (nonatomic, assign) BOOL disableDirectTransfers;

/**
* Use this to disable file transfers via SOCKS5.
*
* If set to YES, SOCKS5 transfers will not be used. This means that the
* recipient must support IBB transfers or the transfer will fail. If set to NO,
* a SOCKS5 connection will be attempted first, since this should be the
* preferred method of transfer.
*
* The default value is NO.
*/
@property (nonatomic, assign) BOOL disableSOCKS5;

/**
* Use this to disable file transfers via IBB.
*
* If set to YES, IBB transfers will not be used. This means that the
* recipient must support SOCKS5 transfers or the transfer will fail. If set to
* NO, a SOCKS5 connection will be attempted first, since this should be the
* preferred method of transfer.
*
* The default value is NO.
*/
@property (nonatomic, assign) BOOL disableIBB;

@end
