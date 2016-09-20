//
//  OMEMOElementTests.m
//  XMPPFrameworkTests
//
//  Created by Chris Ballinger on 9/19/16.
//
//

#import <XCTest/XCTest.h>
#import "XMPPIQ+OMEMO.h"
#import "OMEMOBundle.h"

@interface OMEMOElementTests : XCTestCase

@end

@implementation OMEMOElementTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testDeviceIdSerialization {
    NSArray *deviceIds = @[@(12345), @(4223), @(31415)];
    XMPPIQ *iq = [XMPPIQ omemo_iqForDeviceIds:deviceIds elementId:@"announce1"];
    NSString *iqString = [iq XMLString];
    NSString *expectedString = @" \
    <iq type='set' id='announce1'> \
    <pubsub xmlns='http://jabber.org/protocol/pubsub'> \
    <publish node='urn:xmpp:omemo:0:devicelist'> \
    <item> \
    <list xmlns='urn:xmpp:omemo:0'> \
    <device id='12345' /> \
    <device id='4223' /> \
    <device id='31415' /> \
    </list> \
    </item> \
    </publish> \
    </pubsub> \
    </iq> \
    ";
    NSError *error = nil;
    NSXMLElement *outputIQ = [[NSXMLElement alloc] initWithXMLString:iqString error:&error];
    XCTAssertNil(error);
    NSXMLElement *expectedIQ = [[NSXMLElement alloc] initWithXMLString:expectedString error:&error];
    XCTAssertNil(error);
    
    XCTAssertEqualObjects([outputIQ XMLString], [expectedIQ XMLString]);
}

- (void) testPublishDeviceBundle {
    NSString *expectedString = @" \
    <iq type='set' id='announce2'> \
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
    </iq> \
    ";
    NSError *error = nil;
    NSXMLElement *expectedXML = [[NSXMLElement alloc] initWithXMLString:expectedString error:&error];
    XCTAssertNotNil(expectedXML);
    XCTAssertNil(error);
    NSString *signedPreKeyPublic = @"signedPreKeyPublic";
    NSString *signedPreKeySignature = @"signedPreKeySignature";
    NSString *identityKey = @"identityKey";
    NSString *preKey1 = @"preKey1";
    NSString *preKey2 = @"preKey2";
    NSString *preKey3 = @"preKey3";
    NSData *signedPreKeyPublicData = [signedPreKeyPublic dataUsingEncoding:NSUTF8StringEncoding];
    NSData *signedPreKeySignatureData = [signedPreKeySignature dataUsingEncoding:NSUTF8StringEncoding];
    NSData *identityKeyData = [identityKey dataUsingEncoding:NSUTF8StringEncoding];
    NSData *preKeyData1 = [preKey1 dataUsingEncoding:NSUTF8StringEncoding];
    NSData *preKeyData2 = [preKey2 dataUsingEncoding:NSUTF8StringEncoding];
    NSData *preKeyData3 = [preKey3 dataUsingEncoding:NSUTF8StringEncoding];
    NSArray <OMEMOPreKey*> *preKeys = @[[[OMEMOPreKey alloc] initWithPreKeyId:1 publicKey:preKeyData1],
                         [[OMEMOPreKey alloc] initWithPreKeyId:2 publicKey:preKeyData2],
                         [[OMEMOPreKey alloc] initWithPreKeyId:3 publicKey:preKeyData3]
                        ];
    OMEMOSignedPreKey *signedPreKey = [[OMEMOSignedPreKey alloc] initWithPreKeyId:1 publicKey:signedPreKeyPublicData signature:signedPreKeySignatureData];
    OMEMOBundle *bundle = [[OMEMOBundle alloc] initWithDeviceId:31415 identityKey:identityKeyData signedPreKey:signedPreKey preKeys:preKeys];
    XMPPIQ *iq = [XMPPIQ omemo_iqBundle:bundle elementId:@"announce2"];
    // Test is failing because prekeys dict enumeration is out of order compared to example string
    XCTAssertEqualObjects([iq XMLStringWithOptions:DDXMLNodePrettyPrint], [expectedXML XMLStringWithOptions:DDXMLNodePrettyPrint]);
}


@end
