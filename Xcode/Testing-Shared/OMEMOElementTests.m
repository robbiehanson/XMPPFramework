//
//  OMEMOElementTests.m
//  XMPPFrameworkTests
//
//  Created by Chris Ballinger on 9/19/16.
//
//

#import <XCTest/XCTest.h>
#import "XMPPIQ+OMEMO.h"
#import "XMPPMessage+OMEMO.h"
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
    XCTAssertEqualObjects([iq XMLStringWithOptions:DDXMLNodePrettyPrint], [expectedXML XMLStringWithOptions:DDXMLNodePrettyPrint]);
}

/**
 * iq stanza for fetching remote bundle
 
 <iq type='get'
    to='juliet@capulet.lit'
    id='fetch1'>
  <pubsub xmlns='http://jabber.org/protocol/pubsub'>
    <items node='urn:xmpp:omemo:0:bundles:31415'/>
  </pubsub>
</iq>
 
 */
- (void) testFetchBundleForDeviceId {
    NSString *expected = @" \
    <iq type='get' \
    to='juliet@capulet.lit' \
    id='fetch1'> \
    <pubsub xmlns='http://jabber.org/protocol/pubsub'> \
    <items node='urn:xmpp:omemo:0:bundles:31415'/> \
    </pubsub> \
    </iq> \
    ";
    NSError *error = nil;
    NSXMLElement *expectedElement = [[NSXMLElement alloc] initWithXMLString:expected error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(expectedElement);
    XMPPIQ *iq = [XMPPIQ omemo_iqFetchBundleForDeviceId:31415 jid:[XMPPJID jidWithString:@"juliet@capulet.lit"] elementId:@"fetch1"];
    XCTAssertEqualObjects([iq XMLStringWithOptions:DDXMLNodePrettyPrint], [expectedElement XMLStringWithOptions:DDXMLNodePrettyPrint]);
}

/**
 <encrypted xmlns='urn:xmpp:omemo:0'>
  <header sid='27183'>
    <key rid='31415'>BASE64ENCODED...</key>
    <key rid='12321'>BASE64ENCODED...</key>
    <!-- ... -->
    <iv>BASE64ENCODED...</iv>
  </header>
</encrypted>
 */
- (void) testKeyTransportElement {
    NSString *expected = @" \
    <encrypted xmlns='urn:xmpp:omemo:0'> \
    <header sid='27183'> \
    <key rid='31415'>MzE0MTU=</key> \
    <key rid='12321'>MTIzMjE=</key> \
    <iv>aXY=</iv> \
    </header> \
    </encrypted> \
    ";
    NSXMLElement *expectedElement = [[NSXMLElement alloc] initWithXMLString:expected error:nil];
    XCTAssertNotNil(expectedElement);
    NSString *key1 = @"MzE0MTU=";
    NSString *key2 = @"MTIzMjE=";
    NSString *iv = @"aXY=";
    NSData *keyData1 = [[NSData alloc] initWithBase64EncodedString:key1 options:0];
    NSData *keyData2 = [[NSData alloc] initWithBase64EncodedString:key2 options:0];
    NSData *ivData = [[NSData alloc] initWithBase64EncodedString:iv options:0];
    NSDictionary *keyData = @{@(31415): keyData1,
                              @(12321): keyData2};
    uint32_t senderDeviceId = 27183;
    NSXMLElement *testElement = [NSXMLElement omemo_keyTransportElementForDeviceId:senderDeviceId keyData:keyData iv:ivData];
    
    XCTAssertTrue([expectedElement omemo_isEncryptedElement]);
    XCTAssertTrue([testElement omemo_isEncryptedElement]);
    
    XCTAssertTrue(senderDeviceId == [expectedElement omemo_senderDeviceId]);
    XCTAssertTrue(senderDeviceId == [testElement omemo_senderDeviceId]);
    
    XCTAssertEqualObjects(keyData, [expectedElement omemo_keyData]);
    XCTAssertEqualObjects(keyData, [testElement omemo_keyData]);
    
    XCTAssertNil([expectedElement omemo_payload]);
    XCTAssertNil([testElement omemo_payload]);
}

/*
<iq from='juliet@capulet.lit' type='set' id='announce2'>
  <pubsub xmlns='http://jabber.org/protocol/pubsub'>
    <publish node='urn:xmpp:omemo:0:bundles:31415'>
      <item>
        <bundle xmlns='urn:xmpp:omemo:0'>
          <signedPreKeyPublic signedPreKeyId='1'>
            BASE64ENCODED...
          </signedPreKeyPublic>
          <signedPreKeySignature>
            BASE64ENCODED...
          </signedPreKeySignature>
          <identityKey>
            BASE64ENCODED...
          </identityKey>
          <prekeys>
            <preKeyPublic preKeyId='1'>
              BASE64ENCODED...
            </preKeyPublic>
            <preKeyPublic preKeyId='2'>
              BASE64ENCODED...
            </preKeyPublic>
            <preKeyPublic preKeyId='3'>
              BASE64ENCODED...
            </preKeyPublic>
            <!-- ... -->
          </prekeys>
        </bundle>
      </item>
    </publish>
  </pubsub>
</iq>
 */
- (void) testBundleParsing {
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
    XCTAssertEqualObjects([iq XMLStringWithOptions:DDXMLNodePrettyPrint], [expectedXML XMLStringWithOptions:DDXMLNodePrettyPrint]);
    
    OMEMOBundle *expectedBundle = [[XMPPIQ iqFromElement:expectedXML] omemo_bundle];
    OMEMOBundle *bundle2 = [iq omemo_bundle];
    
    XMPPIQ *expectedIQ = [XMPPIQ omemo_iqBundle:expectedBundle elementId:@"eid"];
    XMPPIQ *bundle2iq = [XMPPIQ omemo_iqBundle:bundle2 elementId:@"eid"];
    
    XCTAssertEqualObjects([expectedIQ XMLStringWithOptions:DDXMLNodePrettyPrint], [bundle2iq XMLStringWithOptions:DDXMLNodePrettyPrint]);
}

@end
