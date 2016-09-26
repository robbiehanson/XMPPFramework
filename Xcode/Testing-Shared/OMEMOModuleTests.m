//
//  OMEMOTests.m
//  XMPPFrameworkTests
//
//  Created by Chris Ballinger on 5/5/16.
//
//

#import <XCTest/XCTest.h>
#import <XMPPFramework/OMEMOModule.h>
#import <XMPPFramework/XMPPIQ+OMEMO.h>
#import "OMEMOTestStorage.h"
#import "XMPPMockStream.h"

@interface OMEMOModuleTests : XCTestCase
@property (nonatomic, strong) OMEMOModule *omemoModule;
@property (nonatomic, strong) XMPPMockStream *mockStream;
@end

@implementation OMEMOModuleTests

- (void)setUp {
    [super setUp];
    OMEMOBundle *bundle = [self bundle];
    XMPPJID *myJID = [XMPPJID jidWithString:@"test@example.com"];
    OMEMOTestStorage *testStorage = [[OMEMOTestStorage alloc] initWithMyBundle:bundle];
    self.omemoModule = [[OMEMOModule alloc] initWithOMEMOStorage:testStorage];
    self.mockStream = [[XMPPMockStream alloc] init];
    self.mockStream.myJID = myJID;
    [self.omemoModule activate:self.mockStream];
    [self.omemoModule addDelegate:self delegateQueue:dispatch_get_main_queue()];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [self.omemoModule removeDelegate:self];
    [self.omemoModule deactivate];
    self.omemoModule = nil;
    self.mockStream = nil;
    [super tearDown];
}

- (void)testPublishDeviceIds {
    
    
    
}

- (void)testPublishBundle {
    
}

- (void)testFetchBundle {
    
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
    <iq'> \
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
    return [XMPPIQ iqFromElement:element];
}

- (NSXMLElement*)innerBundleElement {
    NSString *expectedString = @" \
    <pubsub xmlns='http://jabber.org/protocol/pubsub'> \
    <publish node='urn:xmpp:omemo:0:bundles:31415'> \
    <item> \
    <bundle xmlns='urn:xmpp:omemo:0'> \
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
    ";
    NSXMLElement *element = [[NSXMLElement alloc] initWithXMLString:expectedString error:nil];
    XCTAssertNotNil(element);
    return element;
}

- (OMEMOBundle*) bundle {
    OMEMOBundle *bundle = [[self iq_SetBundleWithEid:@"announce1"] omemo_bundle];
    XCTAssertNotNil(bundle);
    return bundle;
}

#pragma mark OMEMODelegate


@end
