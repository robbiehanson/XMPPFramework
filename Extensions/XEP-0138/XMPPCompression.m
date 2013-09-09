//
//  XMPPCompression.m
//  xmpp
//
//  Created by YANG HONGBO on 2013-9-6.
//  Copyright (c) 2013年 YANG HONGBO. All rights reserved.
//

#import "XMPPCompression.h"
#import "zlib.h"
#import "XMPPLogging.h"
#import "XMPPStreamInternal.h"

#if DEBUG
static const int xmppLogLevel = XMPP_LOG_LEVEL_INFO | XMPP_LOG_FLAG_SEND_RECV; // | XMPP_LOG_FLAG_TRACE;
#else
static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

typedef enum XMPPCompressionState {
    XMPPCompressionStateNegotiating,
    XMPPCompressionStateRequestingCompress,
    XMPPCompressionStateCompressing,
    XMPPCompressionStateFailureUnsupportedMethod,
    XMPPCompressionStateFailureSetupFailed,
}XMPPCompressionState;

static NSString * const XMPPCompressionFeatureNS = @"http://jabber.org/features/compress";
static NSString * const XMPPCompressionProtocolNS = @"http://jabber.org/protocol/compress";

@interface XMPPCompression ()
{
    z_stream _inflation_strm;
    z_stream _deflation_strm;
}
@property (atomic, copy, readwrite) NSString *compressionMethod;
@property (assign, readwrite) XMPPCompressionState compressionState;
@end

@implementation XMPPCompression

+ (NSArray *)supportedCompressionMethods
{
    return @[@"zlib"];
}

- (id)init
{
    self = [super init];
    if (self) {
        memset(&_inflation_strm, 0, sizeof(z_stream));
        memset(&_deflation_strm, 0, sizeof(z_stream));
    }
    return self;
}

- (void)dealloc
{
    [self endCompression];
}

- (void)activate:(XMPPStream *)xmppStream
{
    [super activate:xmppStream];
    [self.xmppStream addElementHandler:self];
    [self.xmppStream addStreamPreprocessor:self];
}

- (void)deactivate
{
    [self.xmppStream removeElementHandler:self];
    [self.xmppStream removeStreamPreprocessor:self];
    [super deactivate];
}

- (BOOL)handleFeatures:(NSXMLElement *)features
{
    XMPPLogTrace();
    if ([self handleCompressionMethods:features]) {
        return YES;
    }
    return NO;
}

- (BOOL)handleElement:(NSXMLElement *)element
{
    if([[element xmlns] isEqualToString:XMPPCompressionProtocolNS]) {
        if ([self handleCompressed:element]) {
            return YES;
        }
        else if ([self handleFailure:element]) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)handleCompressionMethods:(NSXMLElement *)features
{
    XMPPLogTrace();
    
    if (XMPPCompressionStateNegotiating == self.compressionState) {
        NSXMLElement *compression = [features elementForName:@"compression"
                                                       xmlns:XMPPCompressionFeatureNS];
        if (compression) {
            NSArray *methods = [compression elementsForName:@"method"];
            for (NSString *clientSideMethod in [[self class] supportedCompressionMethods]) {
                for (NSXMLElement *method in methods)
                {
                    if ([[method stringValue] isEqualToString:clientSideMethod])
                    {
              
                        XMPPLogVerbose(@"Compression Method: %@", clientSideMethod);
                        self.compressionMethod = clientSideMethod;
                        self.compressionState = XMPPCompressionStateRequestingCompress;
                        NSXMLElement * compress = [NSXMLElement elementWithName:@"compress"
                                                                          xmlns:XMPPCompressionProtocolNS];
                        NSXMLElement * methodChild = [NSXMLElement elementWithName:@"method" stringValue:clientSideMethod];
                        [compress addChild:methodChild];
                        
                        NSString *outgoingStr = [compress compactXMLString];
                        NSData *outgoingData = [outgoingStr dataUsingEncoding:NSUTF8StringEncoding];
                        
                        XMPPLogSend(@"SEND: %@", outgoingStr);
                        
                        [self.xmppStream writeData:outgoingData
                                       withTimeout:TIMEOUT_XMPP_WRITE
                                               tag:TAG_XMPP_WRITE_STREAM];
                        return YES;
                    }
                }
            }
        }
    }
    return NO;
}

- (BOOL)handleCompressed:(NSXMLElement *)element
{
    XMPPLogTrace();
    //Using TLS is the first choice
    if ([self.xmppStream isSecure]) {
        return NO;
    }
    if (XMPPCompressionStateRequestingCompress == self.compressionState) {
        if([[element name] isEqualToString:@"compressed"]) {
            self.compressionState = XMPPCompressionStateCompressing;
            [self prepareCompression];
            [self.xmppStream sendOpeningNegotiation];

            // And start reading in the server's XML stream
            [self.xmppStream readDataWithTimeout:TIMEOUT_XMPP_READ_START tag:TAG_XMPP_READ_START];
            return YES;
        }
    }
    return NO;
}

- (BOOL)handleFailure:(NSXMLElement *)element
{
    BOOL handled = NO;
    
    if([[element name] isEqualToString:@"failure"]) {
        if ([element elementForName:@"unsupported-method"]) {
            self.compressionState = XMPPCompressionStateFailureUnsupportedMethod;
            XMPPLogError(@"Compression Failure: %@", @"unsupported-method");
            handled = YES;
        }
        else if ([element elementForName:@"setup-failed"]) {
            self.compressionState = XMPPCompressionStateFailureSetupFailed;
            XMPPLogError(@"Compression Failure: %@", @"setup-failed");
            handled = YES;
        }
    }
    
    if (handled) {
    }
    return handled;
}

- (void)prepareCompression
{
    inflateInit(&_inflation_strm);
    deflateInit(&_deflation_strm, Z_BEST_COMPRESSION);
}

- (void)endCompression
{
    inflateEnd(&_inflation_strm);
    deflateEnd(&_deflation_strm);
}

- (NSData *)processInputData:(NSData *)data
{
    NSData * returnData = data;
    if (XMPPCompressionStateCompressing == self.compressionState) {
        NSMutableData * newMutableData = nil; //if inflated buffer exceeds buffer size, then use NSMutableData
        NSData * newData = nil;               // else use a NSData instead -- to minize alloca operations
        uLongf offset = 0;
        Bytef output[1024];
        const uLongf outputSz = sizeof(output);
        int ret = Z_ERRNO;
        while (offset < data.length) {
            int flush = Z_NO_FLUSH;
            uLongf blockSz = 256;
            
            Bytef * buf = (Bytef *)data.bytes + offset;
            if (offset + blockSz >= data.length ) {
                blockSz = data.length - offset;
                flush = Z_SYNC_FLUSH;
            }
            
            _inflation_strm.next_in = buf;
            _inflation_strm.avail_in = blockSz;
            _inflation_strm.avail_out = sizeof(output);
            _inflation_strm.next_out = output;

            ret = inflate(&_inflation_strm, flush);
            if (Z_OK == ret || Z_STREAM_END == ret) {
                uLongf sz = outputSz - _inflation_strm.avail_out;
                if (sz) {
                    if (!newData && !newMutableData) {
                        if(Z_NO_FLUSH != flush) {
                            newData = [NSData dataWithBytes:output length:sz];
                        }
                        else {
                             // current output buffer is not enough, so double it
                            newMutableData = [NSMutableData dataWithCapacity:outputSz * 2];
                        }
                    }
                    if (newMutableData) {
                        [newMutableData appendBytes:output length:sz];
                    }
                }
            }
            else {
                _inflation_strm.total_out = 0;
                XMPPLogError(@"Inflation failed: %d(%s)", ret, _inflation_strm.msg);
                newData = [NSData data];
                break;
            }
            offset += blockSz;
        }
        if (!newData) {
            if (newMutableData) {
                newData = [newMutableData copy];
            }
            else {
                newData = nil;
            }
        }
        if (ret >= Z_OK) {
            XMPPLogRecvPost(@"RECV: Compression Rate:%.4f%%(%d/%d)", data.length * 1.0 / newData.length * 100.0f, data.length, newData.length);
        }
        returnData = newData;
    }
    return returnData;
}

- (NSData *)processOutputData:(NSData *)data
{
    NSData * returnData = data;
    if (XMPPCompressionStateCompressing == self.compressionState) {
        const uLongf bufferSize = deflateBound(&_deflation_strm, data.length);
        Bytef * buffer = (Bytef *)malloc(bufferSize);
        int ret = Z_ERRNO;
        if (buffer) {
            _deflation_strm.next_out = buffer;
            _deflation_strm.avail_out = bufferSize;
            _deflation_strm.next_in = (Bytef *)data.bytes;
            _deflation_strm.avail_in = data.length;
            ret = deflate(&_deflation_strm, Z_PARTIAL_FLUSH);

            if (ret >= Z_OK) {
                const uLongf len = bufferSize - _deflation_strm.avail_out;
                XMPPLogSend(@"SEND: Compression Rate:%.4f%%(%ld/%d)", len * 1.0 / data.length * 100.0f, len, data.length);
                returnData = [NSData dataWithBytesNoCopy:buffer length:len freeWhenDone:YES];
            }
            else {
                XMPPLogError(@"Deflation failed:%d(%s)", ret, _deflation_strm.msg?_deflation_strm.msg:"");
                returnData = [@" " dataUsingEncoding:NSUTF8StringEncoding];
            }
            
        }
        else {
            returnData = nil;
            XMPPLogError(@"Cannot alloca enough memory");
        }
    }
    
    return returnData;
}

@end
