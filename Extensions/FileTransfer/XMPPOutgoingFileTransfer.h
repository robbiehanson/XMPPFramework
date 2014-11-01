//
// Created by Jonathon Staff on 10/21/14.
// Copyright (c) 2014 nplexity, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XMPPFileTransfer.h"

@interface XMPPOutgoingFileTransfer : XMPPFileTransfer

/**
* (Required)
*
* The data being sent to the recipient.
*
* If you're using startFileTransfer:, you *MUST* set this prior to calling
* startFileTransfer:.
*/
@property (nonatomic, strong) NSData *outgoingData;

/**
* (Required)
*
* The recipient of your file transfer.
*
* If you're using startFileTransfer:, you *MUST* set this prior to calling
* startFileTransfer:.
*/
@property (nonatomic, strong) XMPPJID *recipientJID;

/**
* (Optional)
*
* The name of the file you're sending.
*
* If you don't provide a filename, one will be generated for you.
*/
@property (nonatomic, copy) NSString *outgoingFileName;

/**
* (Optional)
*
* The description of the file you're sending.
*/
@property (nonatomic, copy) NSString *outgoingFileDescription;

/**
* (Optional)
*
* Specifies whether or not a random name should be generated instead of the
* filename provided. The randomly generated name will retain the same file
* extension as the original name if one was provided
*
* The default is NO; set to YES to generate a random name.
*/
@property (nonatomic, assign) BOOL shouldGenerateRandomName;

/**
* (Optional)
*
* Specifies the default block-size when using IBB file transfers. The default
* value is 4096 (Bytes). If the file recipient requests a smaller block-size,
* it will be halved.
*/
@property (nonatomic, assign) int32_t blockSize;


#pragma mark - Public Methods

/**
* Starts the file transfer. This assumes that at a minimum a recipientJID and
* outgoingData have already been provided.
*
* @param errPtr The address of an error which will be contain a description of
*               the problem if there is one (optional).
*
* @return Returns NO if there is something blatantly wrong (not authorized, no
*         recipientJID, no outgoingData); YES otherwise.
*/
- (BOOL)startFileTransfer:(NSError **)errPtr;

/**
* Sends the provided data to the provided recipient. Use of this method is not
* recommended, as there is no error handling, but you're free to make your own
* choices.
*/
- (BOOL)sendData:(NSData *)data toRecipient:(XMPPJID *)recipient;

/**
* Sends the provided data to the provided recipient. Pass nil for params you
* don't care about.
*
* @param data The data you wish to send (required).
* @param name The filename of the file you're sending (optional).
* @param recipient The recipient of your file transfer (required). Note that a
*                  resource must also be included in the JID.
* @param description The description of the file you're sending (optional).
* @param errPtr The address of an error which will contain a description of the
*               problem if there is one (optional).
*/
- (BOOL)sendData:(NSData *)data
           named:(NSString *)name
     toRecipient:(XMPPJID *)recipient
     description:(NSString *)description
           error:(NSError **)errPtr;

@end


#pragma mark - XMPPOutgoingFileTransferDelegate

@protocol XMPPOutgoingFileTransferDelegate
@optional

/**
* Implement this method when calling startFileTransfer: or sendData:(variants).
* It will be invoked if the file transfer fails to execute properly. More
* information will be given in the error.
*
* @param sender XMPPOutgoingFileTransfer object invoking this delegate method.
* @param error NSError containing more details of the failure.
*/
- (void)xmppOutgoingFileTransfer:(XMPPOutgoingFileTransfer *)sender
                didFailWithError:(NSError *)error;

/**
* Implement this method when calling startFileTransfer: or sendData:(variants).
* It will be invoked if the outgoing file transfer was completed successfully.
*
* @param sender XMPPOutgoingFileTransfer object invoking this delegate method.
*/
- (void)xmppOutgoingFileTransferDidSucceed:(XMPPOutgoingFileTransfer *)sender;

/**
* Not really sure why you would want this information, but hey, when I get
* information, I'm happy to share.
*/
- (void)xmppOutgoingFileTransferIBBClosed:(XMPPOutgoingFileTransfer *)sender;

@end
