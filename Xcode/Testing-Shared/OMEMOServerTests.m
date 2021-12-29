//
//  OMEMOServerTests.m
//  XMPPFrameworkTests
//
//  Created by Chris Ballinger on 9/27/16.
//
//

#import <XCTest/XCTest.h>
#import "OMEMOTestStorage.h"
@import XMPPFramework;
@import CocoaLumberjack;

// These tests aren't suited for automated testing e.g. Travis.
// Uncomment the below line to test on your own machine.
// #define SERVER_TESTS

#ifdef SERVER_TESTS

// Configure a user account on your server and replace the values below.
// Do not commit actual values to source control!
#warning Do not commit actual values to source control!
//#define TEST_USER @"test@example.com"
//#define TEST_PASSWORD @"password"

@interface OMEMOServerTests : XCTestCase <XMPPStreamDelegate, XMPPRosterDelegate, OMEMOModuleDelegate, XMPPCapabilitiesDelegate>
@property (nonatomic, strong) XCTestExpectation *publishDeviceIdsExpectation;
@property (nonatomic, strong) XCTestExpectation *publishBundleExpectation;
@property (nonatomic, strong) XCTestExpectation *fetchBundleExpectation;

@property (nonatomic, strong, readonly) OMEMOBundle *myBundle;
@property (nonatomic, strong, readonly) XMPPStream *stream;
@property (nonatomic, strong, readonly) XMPPRoster *roster;
@property (nonatomic, strong, readonly) OMEMOModule *omemoModule;
@property (nonatomic, strong, readonly) XMPPCapabilities *capabilities;
@end

@implementation OMEMOServerTests

- (void)setUp {
    [super setUp];
    [DDLog addLogger:[DDTTYLogger sharedInstance]];

    // Put setup code here. This method is called before the invocation of each test method in the class.
    _stream = [[XMPPStream alloc] init];
    self.stream.myJID = [XMPPJID jidWithString:TEST_USER];
    [self.stream addDelegate:self delegateQueue:dispatch_get_main_queue()];
    
    XMPPRosterMemoryStorage *inMemoryStorage = [[XMPPRosterMemoryStorage alloc] init];
    _roster = [[XMPPRoster alloc] initWithRosterStorage:inMemoryStorage];
    [self.roster addDelegate:self delegateQueue:dispatch_get_main_queue()];
    [self.roster activate:self.stream];
    
    _myBundle = [OMEMOTestStorage testBundle];
    OMEMOTestStorage *storage = [[OMEMOTestStorage alloc] initWithMyBundle:self.myBundle];
    _omemoModule = [[OMEMOModule alloc] initWithOMEMOStorage:storage];
    [self.omemoModule addDelegate:self delegateQueue:dispatch_get_main_queue()];
    [self.omemoModule activate:self.stream];
    
     XMPPCapabilitiesCoreDataStorage *xmppCapabilitiesStorage = [[XMPPCapabilitiesCoreDataStorage alloc] initWithInMemoryStore];
    _capabilities = [[XMPPCapabilities alloc] initWithCapabilitiesStorage:xmppCapabilitiesStorage];
    self.capabilities.autoFetchNonHashedCapabilities = YES;
    self.capabilities.autoFetchMyServerCapabilities = YES;
    [self.capabilities addDelegate:self delegateQueue:dispatch_get_main_queue()];
    [self.capabilities activate:self.stream];
    
}

- (void)tearDown {
    NSLog(@"%@: %@", THIS_FILE, THIS_METHOD);
    
    [self.roster deactivate];
    [self.roster removeDelegate:self];
    _roster = nil;
    
    [self.omemoModule deactivate];
    [self.omemoModule removeDelegate:self];
    _omemoModule = nil;
    
    [self.stream disconnect];
    [self.stream removeDelegate:self];
    _stream = nil;
    
    [self.capabilities deactivate];
    [self.capabilities removeDelegate:self];
    _capabilities = nil;
    
    [DDLog removeAllLoggers];
    [super tearDown];
}

- (void)testOMEMOModule {
    self.publishDeviceIdsExpectation = [self expectationWithDescription:@"publishDeviceIdsExpectation"];
    self.publishBundleExpectation = [self expectationWithDescription:@"publishBundleExpectation"];
    self.fetchBundleExpectation = [self expectationWithDescription:@"fetchBundleExpectation"];
    NSError *error = nil;
    BOOL success = [self.stream connectWithTimeout:XMPPStreamTimeoutNone error:&error];
    XCTAssertTrue(success);
    XCTAssertNil(error);
    
    [self waitForExpectationsWithTimeout:60 handler:^(NSError * _Nullable error) {
        if(error){
            XCTFail(@"Expectation Failed with error: %@", error);
        }
    }];
}

#pragma mark XMPPStreamDelegate

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message {
    NSLog(@"%@: %@", THIS_FILE, THIS_METHOD);
}


- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq {
    NSLog(@"%@: %@", THIS_FILE, THIS_METHOD);
    return NO;
}

- (void)xmppStreamDidConnect:(XMPPStream *)sender {
    NSLog(@"%@: %@", THIS_FILE, THIS_METHOD);
    NSError *error = nil;
    BOOL success = [sender authenticateWithPassword:TEST_PASSWORD error:nil];
    XCTAssertTrue(success);
    XCTAssertNil(error);
}

- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender {
    NSLog(@"%@: %@", THIS_FILE, THIS_METHOD);
    //[self.expectation fulfill];
    
    [self.stream sendElement:[XMPPPresence presence]];
    [self.omemoModule publishDeviceIds:@[@(31415)] elementId:nil];
    [self.omemoModule publishBundle:self.myBundle elementId:nil];
}

- (void)xmppStream:(XMPPStream *)sender didReceivePresence:(XMPPPresence *)presence
{
    NSLog(@"%@: %@ - %@\nType: %@\nShow: %@\nStatus: %@", THIS_FILE, THIS_METHOD, [presence from], [presence type], [presence show],[presence status]);
}


#pragma mark XMPPRosterDelegate


- (void)xmppRoster:(XMPPRoster *)sender didReceiveRosterItem:(NSXMLElement *)item {
    NSLog(@"%@: %@", THIS_FILE, THIS_METHOD);
    NSString *jidString = [item attributeStringValueForName:@"jid"];
    XMPPJID *jid = [XMPPJID jidWithString:jidString];
    XCTAssertNotNil(jid);
    //[self.capabilities fetchCapabilitiesForJID:jid];
    //[self.omemoModule fetchDeviceIdsForJID:jid elementId:nil];
}

#pragma mark XMPPCapabilitiesDelegate

/**
 * Use this delegate method to add specific capabilities.
 * This method in invoked automatically when the stream is connected for the first time,
 * or if the module detects an outgoing presence element and my capabilities haven't been collected yet
 *
 * The design of XEP-115 is such that capabilites are expected to remain rather static.
 * However, if the capabilities change, the recollectMyCapabilities method may be used to perform a manual update.
 **/
- (void)xmppCapabilities:(XMPPCapabilities *)sender collectingMyCapabilities:(NSXMLElement *)query {
    NSLog(@"%@: %@", THIS_FILE, THIS_METHOD);
}


/**
 * Use this delegate method to return the feature you want to have in your capabilities e.g. @[@"urn:xmpp:archive"]
 * Duplicate features are automatically discarded
 * For more control over your capablities use xmppCapabilities:collectingMyCapabilities:
 **/
- (NSArray *)myFeaturesForXMPPCapabilities:(XMPPCapabilities *)sender {
    NSLog(@"%@: %@", THIS_FILE, THIS_METHOD);
    return nil;
}

/**
 * Invoked when capabilities have been discovered for an available JID.
 *
 * The caps element is the <query/> element response to a disco#info request.
 **/
- (void)xmppCapabilities:(XMPPCapabilities *)sender didDiscoverCapabilities:(NSXMLElement *)caps forJID:(XMPPJID *)jid {
    NSLog(@"%@: %@", THIS_FILE, THIS_METHOD);
}

#pragma mark OMEMOModuleDelegate

/** Failed to fetch deviceList */
- (void)omemo:(OMEMOModule*)omemo failedToFetchDeviceIdsForJID:(XMPPJID*)fromJID errorIq:(nullable XMPPIQ*)errorIq
   outgoingIq:(XMPPIQ*)outgoingIq {
    NSLog(@"%@: %@", THIS_FILE, THIS_METHOD);
    //XCTFail(@"Failed.");
}

/** Callback for when your device list is successfully published */
- (void)omemo:(OMEMOModule*)omemo
publishedDeviceIds:(NSArray<NSNumber*>*)deviceIds
   responseIq:(XMPPIQ*)responseIq
   outgoingIq:(XMPPIQ*)outgoingIq {
    NSLog(@"%@: %@", THIS_FILE, THIS_METHOD);
    [self.publishDeviceIdsExpectation fulfill];
}

/** Callback for when your device list update fails. If errorIq is nil there was a timeout. */
- (void)omemo:(OMEMOModule*)omemo
failedToPublishDeviceIds:(NSArray<NSNumber*>*)deviceIds
      errorIq:(nullable XMPPIQ*)errorIq
   outgoingIq:(XMPPIQ*)outgoingIq {
    NSLog(@"%@: %@", THIS_FILE, THIS_METHOD);
}


/**
 * In order to determine whether a given contact has devices that support OMEMO, the devicelist node in PEP is consulted. Devices MUST subscribe to 'urn:xmpp:omemo:0:devicelist' via PEP, so that they are informed whenever their contacts add a new device. They MUST cache the most up-to-date version of the devicelist.
 */
- (void)omemo:(OMEMOModule*)omemo deviceListUpdate:(NSArray<NSNumber*>*)deviceIds fromJID:(XMPPJID*)fromJID incomingElement:(NSXMLElement*)incomingElement {
    NSLog(@"%@: %@ %@ %@", THIS_FILE, THIS_METHOD, deviceIds, fromJID);
    [deviceIds enumerateObjectsUsingBlock:^(NSNumber * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self.omemoModule fetchBundleForDeviceId:(uint32_t)obj.unsignedIntegerValue jid:fromJID elementId:nil];
    }];
}

/** Callback for when your bundle is successfully published */
- (void)omemo:(OMEMOModule*)omemo
publishedBundle:(OMEMOBundle*)bundle
   responseIq:(XMPPIQ*)responseIq
   outgoingIq:(XMPPIQ*)outgoingIq {
    NSLog(@"%@: %@", THIS_FILE, THIS_METHOD);
    [self.publishBundleExpectation fulfill];
}

/** Callback when publishing your bundle fails */
- (void)omemo:(OMEMOModule*)omemo
failedToPublishBundle:(OMEMOBundle*)bundle
      errorIq:(nullable XMPPIQ*)errorIq
   outgoingIq:(XMPPIQ*)outgoingIq {
    NSLog(@"%@: %@", THIS_FILE, THIS_METHOD);
}

/**
 * Process the incoming OMEMO bundle somewhere in your application
 */
- (void)omemo:(OMEMOModule*)omemo
fetchedBundle:(OMEMOBundle*)bundle
      fromJID:(XMPPJID*)fromJID
   responseIq:(XMPPIQ*)responseIq
   outgoingIq:(XMPPIQ*)outgoingIq {
    NSLog(@"%@: %@ %@ %@ %@", THIS_FILE, THIS_METHOD, fromJID, bundle, responseIq.prettyXMLString);
    XCTAssertNotNil(bundle);
    XCTAssertNotNil(fromJID);
    XCTAssertNotNil(responseIq);
    XCTAssertNotNil(outgoingIq);
    if (self.fetchBundleExpectation) {
        [self.fetchBundleExpectation fulfill];
        self.fetchBundleExpectation = nil;
    }
}

/** Bundle fetch failed */
- (void)omemo:(OMEMOBundle*)omemo
failedToFetchBundleForDeviceId:(uint32_t)deviceId
      fromJID:(XMPPJID*)fromJID
      errorIq:(nullable XMPPIQ*)errorIq
   outgoingIq:(XMPPIQ*)outgoingIq {
    NSLog(@"%@: %@", THIS_FILE, THIS_METHOD);
}

/**
 * Incoming MessageElement payload, keyData, and IV. If no payload it's a KeyTransportElement
 - (void)omemo:(OMEMOModule*)omemo
 failedToSendKeyData:(NSDictionary<NSNumber*,NSData*>*)keyData
 iv:(NSData*)iv
 toJID:(XMPPJID*)toJID
 payload:(nullable NSData*)payload
 errorMessage:(nullable XMPPMessage*)errorMessage
 outgoingMessage:(XMPPMessage*)outgoingMessage;
 */

/**
 * Incoming MessageElement payload, keyData, and IV. If no payload it's a KeyTransportElement */
- (void)omemo:(OMEMOModule*)omemo
receivedKeyData:(NSDictionary<NSNumber*,NSData*>*)keyData
           iv:(NSData*)iv
senderDeviceId:(uint32_t)senderDeviceId
      fromJID:(XMPPJID*)fromJID
      payload:(nullable NSData*)payload
      message:(XMPPMessage*)message {
    NSLog(@"%@: %@", THIS_FILE, THIS_METHOD);
}


@end

#endif
