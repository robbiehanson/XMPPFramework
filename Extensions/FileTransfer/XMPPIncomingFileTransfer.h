//
// Created by Jonathon Staff on 10/21/14.
// Copyright (c) 2014 nplexity, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XMPPFileTransfer.h"

@class XMPPIQ;

@interface XMPPIncomingFileTransfer : XMPPFileTransfer

/**
* (Optional)
*
* Specifies whether or not file transfers should automatically be accepted. If
* set to YES, you will be notified of an incoming Stream Initiation Offer, but
* it will be accepted for you.
*
* The default value is NO.
*/
@property (nonatomic, assign) BOOL autoAcceptFileTransfers;

/**
* Sends a response to the file transfer initiator accepting the Stream
* Initiation offer. It will automatically determine the best transfer method
* (either SOCKS5 or IBB) based on what the sender offers as options.
*
* If you've set autoAcceptFileTransfers to YES, this method will be invoked for
* you automatically.
*
* @param offer IQ stanza representing the SI offer (this should be provided by
*              the delegate to you).
*/
- (void)acceptSIOffer:(XMPPIQ *)offer;

@end


#pragma mark - XMPPIncomingFileTransferDelegate

@protocol XMPPIncomingFileTransferDelegate
@optional

/**
* Implement this method to receive notifications of a failed incoming file
* transfer.
*
* @param sender XMPPIncomingFileTransfer object invoking this delegate method.
* @param error NSError containing more details of the failure.
*/
- (void)xmppIncomingFileTransfer:(XMPPIncomingFileTransfer *)sender
                didFailWithError:(NSError *)error;

/**
* Implement this method to receive notification of an incoming Stream
* Initiation offer. Keep in mind that if you haven't set
* autoAcceptFileTransfers to YES, then it will be your responsibility to call
* acceptSIOffer: using the sender and offer provided to you.
*
* @param sender XMPPIncomingFileTransfer object invoking this delegate method.
* @param offer IQ stanza containing a Stream Initiation offer.
*/
- (void)xmppIncomingFileTransfer:(XMPPIncomingFileTransfer *)sender
               didReceiveSIOffer:(XMPPIQ *)offer;

/**
* Implement this method to receive notifications of a successful incoming file
* transfer. It will only be invoked if all of the data is received
* successfully.
*
* @param sender XMPPIncomingFileTransfer object invoking this delegate method.
* @param data NSData for you to handle (probably save this or display it).
* @param named Name of the file you just received.
*/
- (void)xmppIncomingFileTransfer:(XMPPIncomingFileTransfer *)sender
              didSucceedWithData:(NSData *)data
                           named:(NSString *)name;

@end
