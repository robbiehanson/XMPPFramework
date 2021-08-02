//
//  OMEMOTests.m
//  XMPPFrameworkTests
//
//  Created by Chris Ballinger on 5/5/16.
//
//

#import <XCTest/XCTest.h>
@import XMPPFramework;
@import CocoaLumberjack;

#import "OMEMOTestStorage.h"
#import "XMPPMockStream.h"

@interface OMEMOModuleTests : XCTestCase <OMEMOModuleDelegate>
@property (nonatomic, strong, readonly) OMEMOModule *omemoModule;
@property (nonatomic, strong, readonly) XMPPMockStream *mockStream;
@property (nonatomic, strong) XCTestExpectation *expectation;
@end

@implementation OMEMOModuleTests

- (void)setUp {
    [super setUp];
    
// Comment this out to test legacy namespace
#define OMEMOMODULE_XMLNS_OMEMO
    
#ifdef OMEMOMODULE_XMLNS_OMEMO
    OMEMOModuleNamespace ns = OMEMOModuleNamespaceOMEMO;
#else
    OMEMOModuleNamespace ns = OMEMOModuleNamespaceConversationsLegacy;
#endif
    
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    OMEMOBundle *bundle = [self bundle];
    XMPPJID *myJID = [XMPPJID jidWithString:@"test@example.com"];
    OMEMOTestStorage *testStorage = [[OMEMOTestStorage alloc] initWithMyBundle:bundle];
    _omemoModule = [[OMEMOModule alloc] initWithOMEMOStorage:testStorage xmlNamespace:ns];
    _mockStream = [[XMPPMockStream alloc] init];
    self.mockStream.myJID = myJID;
    [self.omemoModule activate:self.mockStream];
    [self.omemoModule addDelegate:self delegateQueue:dispatch_get_main_queue()];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [self.omemoModule removeDelegate:self];
    [self.omemoModule deactivate];
    _omemoModule = nil;
    _mockStream = nil;
    [DDLog removeAllLoggers];
    [super tearDown];
}

- (void)testFetchDeviceIds {
    self.expectation = [self expectationWithDescription:@"testFetchDeviceIds"];
    
    XMPPJID *testJID = [XMPPJID jidWithString:@"test@example.com"];
    
    OMEMOModuleNamespace ns = self.omemoModule.xmlNamespace;
    NSString *items = [NSString stringWithFormat:@" \
    <pubsub xmlns='http://jabber.org/protocol/pubsub'> \
    <items node='%@'> \
    <item> \
    <list xmlns='%@'> \
    <device id='12345' /> \
    <device id='4223' /> \
    </list> \
    </item> \
    </items> \
    </pubsub> \
                       ", [OMEMOModule xmlnsOMEMODeviceList:ns], [OMEMOModule xmlnsOMEMO:ns]];
    
    NSError *error = nil;
    NSXMLElement *pubsub = [[NSXMLElement alloc] initWithXMLString:items error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(pubsub);
    
    __weak typeof(self) weakSelf = self;
    __weak typeof(XMPPMockStream) *weakStream = self.mockStream;
    self.mockStream.elementReceived = ^void(XMPPIQ *outgoingIq) {
        //Fixes warning about retain cycle
        typeof(self) self = weakSelf;
        NSLog(@"testFetchDeviceIds: %@", outgoingIq);
        XCTAssertNil([[outgoingIq from] resource],"The to jid cannot have a resource. It needs to be a bare JID");
        XMPPIQ *responseIq = [XMPPIQ iqWithType:@"result" to:[outgoingIq from] elementID:outgoingIq.elementID child:[pubsub copy]];
        [weakStream fakeResponse:responseIq];
    };
    
    [self.omemoModule fetchDeviceIdsForJID:testJID elementId:nil];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError * _Nullable error) {
        if(error){
            XCTFail(@"Expectation Failed with error: %@", error);
        }
    }];
}

- (void)testPublishDeviceIds {
    self.expectation = [self expectationWithDescription:@"testPublishDeviceIds"];
    //__weak typeof(self) weakSelf = self;
    __weak typeof(XMPPMockStream) *weakStream = self.mockStream;
    self.mockStream.elementReceived = ^void(XMPPIQ *outgoingIq) {
        NSLog(@"testPublishDeviceIds: %@", outgoingIq);
        XMPPIQ *responseIq = [XMPPIQ iqWithType:@"result" elementID:outgoingIq.elementID];
        [weakStream fakeResponse:responseIq];
    };
    
    NSArray<NSNumber*> *deviceIds = @[@(12345), @(31415)];
    [self.omemoModule publishDeviceIds:deviceIds elementId:nil];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError * _Nullable error) {
        if(error){
            XCTFail(@"Expectation Failed with error: %@", error);
        }
    }];
}

- (void) testPublishDeviceIdsFail {
    self.expectation = [self expectationWithDescription:@"testPublishDeviceIdsFail"];
    //__weak typeof(self) weakSelf = self;
    __weak typeof(XMPPMockStream) *weakStream = self.mockStream;
    self.mockStream.elementReceived = ^void(XMPPIQ *outgoingIq) {
        NSLog(@"testPublishDeviceIdsError: %@", outgoingIq);
        XMPPIQ *responseIq = [XMPPIQ iqWithType:@"error" elementID:outgoingIq.elementID];
        [weakStream fakeResponse:responseIq];
    };
    
    NSArray<NSNumber*> *deviceIds = @[@(12345), @(31415)];
    [self.omemoModule publishDeviceIds:deviceIds elementId:nil];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError * _Nullable error) {
        if(error){
            XCTFail(@"Expectation Failed with error: %@", error);
        }
    }];
}

- (void)testPublishBundle {
    self.expectation = [self expectationWithDescription:@"testPublishBundle"];
    //__weak typeof(self) weakSelf = self;
    __weak typeof(XMPPMockStream) *weakStream = self.mockStream;
    self.mockStream.elementReceived = ^void(XMPPIQ *outgoingIq) {
        NSLog(@"testPublishBundle: %@", outgoingIq);
        XMPPIQ *responseIq = [XMPPIQ iqWithType:@"result" elementID:outgoingIq.elementID];
        [weakStream fakeResponse:responseIq];
    };
    
    OMEMOBundle *myBundle = [self.omemoModule.omemoStorage fetchMyBundle];
    XCTAssertNotNil(myBundle);
    [self.omemoModule publishBundle:myBundle elementId:nil];
    
    [self waitForExpectationsWithTimeout:30 handler:^(NSError * _Nullable error) {
        if(error){
            XCTFail(@"Expectation Failed with error: %@", error);
        }
    }];
}

- (void)testPublishBundleFail {
    self.expectation = [self expectationWithDescription:@"testPublishBundleFail"];
    //__weak typeof(self) weakSelf = self;
    __weak typeof(XMPPMockStream) *weakStream = self.mockStream;
    self.mockStream.elementReceived = ^void(XMPPIQ *outgoingIq) {
        NSLog(@"testPublishBundleFail: %@", outgoingIq);
        XMPPIQ *responseIq = [XMPPIQ iqWithType:@"error" elementID:outgoingIq.elementID];
        [weakStream fakeResponse:responseIq];
    };
    
    OMEMOBundle *myBundle = [self.omemoModule.omemoStorage fetchMyBundle];
    XCTAssertNotNil(myBundle);
    [self.omemoModule publishBundle:myBundle elementId:nil];
    
    [self waitForExpectationsWithTimeout:30 handler:^(NSError * _Nullable error) {
        if(error){
            XCTFail(@"Expectation Failed with error: %@", error);
        }
    }];
}

- (void) testFetchBundle {
    XMPPJID *remoteJID = [XMPPJID jidWithString:@"remote@jid.com"];
    self.expectation = [self expectationWithDescription:@"testFetchBundle"];
    __weak typeof(self) weakSelf = self;
    __weak typeof(XMPPMockStream) *weakStream = self.mockStream;
    self.mockStream.elementReceived = ^void(XMPPIQ *outgoingIq) {
        NSLog(@"testFetchBundle: %@", outgoingIq);
        XMPPIQ *iq = [weakSelf iq_resultBundleFromJID:remoteJID eid:outgoingIq.elementID];
        [weakStream fakeResponse:iq];
    };
    
    [self.omemoModule fetchBundleForDeviceId:31415 jid:remoteJID elementId:nil];
    
    [self waitForExpectationsWithTimeout:30 handler:^(NSError * _Nullable error) {
        if(error){
            XCTFail(@"Expectation Failed with error: %@", error);
        }
    }];
}

- (void) testFetchBundleFail {
    XMPPJID *remoteJID = [XMPPJID jidWithString:@"remote@jid.com"];
    self.expectation = [self expectationWithDescription:@"testFetchFail"];
    __weak typeof(self) weakSelf = self;
    __weak typeof(XMPPMockStream) *weakStream = self.mockStream;
    self.mockStream.elementReceived = ^void(XMPPIQ *outgoingIq) {
        NSLog(@"testFetchFail: %@", outgoingIq);
        XMPPIQ *responseIq = [weakSelf iq_errorFromJID:remoteJID eid:outgoingIq.elementID];
        [weakStream fakeResponse:responseIq];
    };
    
    [self.omemoModule fetchBundleForDeviceId:31415 jid:remoteJID elementId:nil];
    
    [self waitForExpectationsWithTimeout:30 handler:^(NSError * _Nullable error) {
        if(error){
            XCTFail(@"Expectation Failed with error: %@", error);
        }
    }];
}

- (void) testSendKeyData {
    XMPPJID *remoteJID = [XMPPJID jidWithString:@"remote@jid.com"];
    self.expectation = [self expectationWithDescription:@"testSendKeyData"];
    __weak typeof(self) weakSelf = self;
    //__weak typeof(XMPPMockStream) *weakStream = self.mockStream;
    self.mockStream.elementReceived = ^void(XMPPMessage *outgoingMessage) {
        NSLog(@"testSendKeyData: %@", outgoingMessage);
        [weakSelf.expectation fulfill];
    };
    
    NSString *key1 = @"MzE0MTU=";
    NSString *key2 = @"MTIzMjE=";
    NSString *iv = @"aXY=";
    NSString *payload = @"cGF5bG9hZA==";
    NSData *keyData1 = [[NSData alloc] initWithBase64EncodedString:key1 options:0];
    NSData *keyData2 = [[NSData alloc] initWithBase64EncodedString:key2 options:0];
    NSData *ivData = [[NSData alloc] initWithBase64EncodedString:iv options:0];
    NSData *payloadData = [[NSData alloc] initWithBase64EncodedString:payload options:0];
    
    NSArray *keyData = @[[[OMEMOKeyData alloc] initWithDeviceId:31415 data:keyData1 isPreKey:NO],
    [[OMEMOKeyData alloc] initWithDeviceId:12321 data:keyData2 isPreKey:YES]];
    
    [self.omemoModule sendKeyData:keyData iv:ivData toJID:remoteJID payload:payloadData elementId:nil];
    
    [self waitForExpectationsWithTimeout:30 handler:^(NSError * _Nullable error) {
        if(error){
            XCTFail(@"Expectation Failed with error: %@", error);
        }
    }];
}

- (void) testReceiveMessage {
    OMEMOModuleNamespace ns = self.omemoModule.xmlNamespace;

    NSString *incoming = [NSString stringWithFormat:@" \
    <message to=\"remote@jid.com\" from=\"local@jid.com\" id=\"6441EEB7-89E6-4D02-8899-BB0E3E1C0EB2\"><store xmlns=\"urn:xmpp:hints\"></store><encrypted xmlns=\"%@\"><header sid=\"31415\"><key rid=\"12321\">MTIzMjE=</key><key rid=\"31415\">MzE0MTU=</key><iv>aXY=</iv></header><payload>cGF5bG9hZA==</payload></encrypted></message> \
    ", [OMEMOModule xmlnsOMEMO:ns]];
    
    self.expectation = [self expectationWithDescription:@"testReceiveMessage"];
    NSXMLElement *element = [[NSXMLElement alloc] initWithXMLString:incoming error:nil];
    XCTAssertNotNil(element);
    [self.mockStream fakeResponse:element];
    
    [self waitForExpectationsWithTimeout:30 handler:^(NSError * _Nullable error) {
        if(error){
            XCTFail(@"Expectation Failed with error: %@", error);
        }
    }];
}

- (void) testDeviceListUpdate {
    OMEMOModuleNamespace ns = self.omemoModule.xmlNamespace;

    NSString *incoming = [NSString stringWithFormat:@" \
    <message from='juliet@capulet.lit' \
    to='romeo@montague.lit' \
    type='headline' \
    id='update_01'> \
    <event xmlns='http://jabber.org/protocol/pubsub#event'> \
    <items node='%@'> \
    <item> \
    <list xmlns='%@'> \
    <device id='12345' /> \
    <device id='4223' /> \
    </list> \
    </item> \
    </items> \
    </event> \
    </message> \
    ", [OMEMOModule xmlnsOMEMODeviceList:ns], [OMEMOModule xmlnsOMEMO:ns]];
    NSXMLElement *element = [[NSXMLElement alloc] initWithXMLString:incoming error:nil];
    self.expectation = [self expectationWithDescription:@"testDeviceListUpdate"];
    XCTAssertNotNil(element);
    [self.mockStream fakeResponse:element];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError * _Nullable error) {
        if(error){
            XCTFail(@"Expectation Failed with error: %@", error);
        }
    }];
}

#pragma mark OMEMODelegate

/** Callback for when your device list is successfully published */
- (void)omemo:(OMEMOModule*)omemo
publishedDeviceIds:(NSArray<NSNumber*>*)deviceIds
   responseIq:(XMPPIQ*)responseIq
   outgoingIq:(XMPPIQ*)outgoingIq {
    // This can be called by testFetchDeviceIds because it will
    // update the device list
    if (self.expectation) {
        [self.expectation fulfill];
        self.expectation = nil;
    }
}

/** Callback for when your device list update fails. If errorIq is nil there was a timeout. */
- (void)omemo:(OMEMOModule*)omemo
failedToPublishDeviceIds:(NSArray<NSNumber*>*)deviceIds
      errorIq:(nullable XMPPIQ*)errorIq
   outgoingIq:(XMPPIQ*)outgoingIq {
    [self.expectation fulfill];
}

/** Callback for when your bundle is successfully published */
- (void)omemo:(OMEMOModule*)omemo
publishedBundle:(OMEMOBundle*)bundle
   responseIq:(XMPPIQ*)responseIq
   outgoingIq:(XMPPIQ*)outgoingIq {
    [self.expectation fulfill];
}

/** Callback when publishing your bundle fails */
- (void)omemo:(OMEMOModule*)omemo
failedToPublishBundle:(OMEMOBundle*)bundle
      errorIq:(nullable XMPPIQ*)errorIq
   outgoingIq:(XMPPIQ*)outgoingIq {
    [self.expectation fulfill];
}

/**
 * Process the incoming OMEMO bundle somewhere in your application
 */
- (void)omemo:(OMEMOModule*)omemo
fetchedBundle:(OMEMOBundle*)bundle
      fromJID:(XMPPJID*)fromJID
   responseIq:(XMPPIQ*)responseIq
   outgoingIq:(XMPPIQ*)outgoingIq {
    [self.expectation fulfill];
}

/** Bundle fetch failed */
- (void)omemo:(OMEMOBundle*)omemo
failedToFetchBundleForDeviceId:(uint32_t)deviceId
      fromJID:(XMPPJID*)fromJID
      errorIq:(nullable XMPPIQ*)errorIq
   outgoingIq:(XMPPIQ*)outgoingIq {
    [self.expectation fulfill];
}

- (void)omemo:(OMEMOModule *)omem removedBundleId:(uint32_t)bundleId responseIq:(XMPPIQ *)responseIq outgoingIq:(XMPPIQ *)outgoingIq elementId:(NSString *)elementId {
    if (self.expectation) {
        [self.expectation fulfill];
        self.expectation = nil;
    }
}

- (void)omemo:(OMEMOModule *)omemo failedToRemoveBundleId:(uint32_t)bundleId errorIq:(nullable XMPPIQ *)errorIq outgoingIq:(nonnull XMPPIQ *)outgoingIq elementId:(nullable NSString *)elementId
{
    if (self.expectation) {
        [self.expectation fulfill];
        self.expectation = nil;
    }
}

/**
 * Incoming MessageElement payload, keyData, and IV. If no payload it's a KeyTransportElement */
- (void)omemo:(OMEMOModule*)omemo
receivedKeyData:(NSDictionary<NSNumber*,NSData*>*)keyData
           iv:(NSData*)iv
senderDeviceId:(uint32_t)senderDeviceId
      fromJID:(XMPPJID*)fromJID
      payload:(nullable NSData*)payload
      message:(XMPPMessage*)message {
    [self.expectation fulfill];
}

/**
 * In order to determine whether a given contact has devices that support OMEMO, the devicelist node in PEP is consulted. Devices MUST subscribe to 'urn:xmpp:omemo:0:devicelist' via PEP, so that they are informed whenever their contacts add a new device. They MUST cache the most up-to-date version of the devicelist.
 */
- (void)omemo:(OMEMOModule*)omemo deviceListUpdate:(NSArray<NSNumber*>*)deviceIds fromJID:(XMPPJID*)fromJID incomingElement:(NSXMLElement*)incomingElement {
    if (self.expectation) {
        [self.expectation fulfill];
        self.expectation = nil;
    }
}

#pragma mark Utility

- (XMPPIQ*) iq_SetBundleWithEid:(NSString*)eid {
    NSXMLElement *inner = [self innerBundleElement];
    XMPPIQ *setIq = [XMPPIQ iqWithType:@"set" elementID:eid child:inner];
    XCTAssertNotNil(setIq);
    return setIq;
}

- (XMPPIQ*) iq_resultBundleFromJID:(XMPPJID*)fromJID eid:(NSString*)eid {
    NSXMLElement *inner = [self innerBundleElement];
    XMPPIQ *iq = [self iq_testIQFromJID:fromJID eid:eid type:@"result"];
    [iq addChild:inner];
    return iq;
}

- (XMPPIQ*) iq_errorFromJID:(XMPPJID*)fromJID eid:(NSString*)eid {
    return [self iq_testIQFromJID:fromJID eid:eid type:@"error"];
}

- (XMPPIQ*) iq_testIQFromJID:(XMPPJID*)fromJID eid:(NSString*)eid type:(NSString*)type {
    NSString *expectedString = @" \
    <iq> \
    </iq> \
    ";
    NSXMLElement *element = [[NSXMLElement alloc] initWithXMLString:expectedString error:nil];
    if (eid) {
        [element addAttributeWithName:@"id" stringValue:eid];
    }
    if (type) {
        [element addAttributeWithName:@"type" stringValue:type];
    }
    if (fromJID) {
        [element addAttributeWithName:@"from" stringValue:[fromJID full]];
    }
    XCTAssertNotNil(element);
    XMPPIQ *iq = [XMPPIQ iqFromElement:element];
    XCTAssertNotNil(iq);
    return iq;
}

- (NSXMLElement*)innerBundleElement {
    OMEMOModuleNamespace ns = self.omemoModule.xmlNamespace;
    NSString *expectedString = [NSString stringWithFormat:@" \
    <pubsub xmlns='http://jabber.org/protocol/pubsub'> \
    <publish node='%@:31415'> \
    <item> \
    <bundle xmlns='%@'> \
    <signedPreKeyPublic signedPreKeyId='1'>c2lnbmVkUHJlS2V5UHVibGlj</signedPreKeyPublic> \
    <signedPreKeySignature>c2lnbmVkUHJlS2V5U2lnbmF0dXJl</signedPreKeySignature> \
    <identityKey>aWRlbnRpdHlLZXk=</identityKey> \
    <prekeys> \
    <preKeyPublic preKeyId='1'>cHJlS2V5MQ==</preKeyPublic> \
    <preKeyPublic preKeyId='2'>cHJlS2V5Mg==</preKeyPublic> \
    <preKeyPublic preKeyId='3'>cHJlS2V5Mw==</preKeyPublic> \
    </prekeys> \
    </bundle> \
    </item> \
    </publish> \
    </pubsub> \
    ", [OMEMOModule xmlnsOMEMOBundles:ns], [OMEMOModule xmlnsOMEMO:ns]];
    NSXMLElement *element = [[NSXMLElement alloc] initWithXMLString:expectedString error:nil];
    XCTAssertNotNil(element);
    return element;
}

- (OMEMOBundle*) bundle {
    OMEMOModuleNamespace ns = self.omemoModule.xmlNamespace;
    OMEMOBundle *bundle = [[self iq_SetBundleWithEid:@"announce1"] omemo_bundle:ns];
    XCTAssertNotNil(bundle);
    return bundle;
}


@end
