//
//  OMEMOElementTests.m
//  XMPPFrameworkTests
//
//  Created by Chris Ballinger on 9/19/16.
//
//

#import <XCTest/XCTest.h>
@import XMPPFramework;

@interface OMEMOElementTests : XCTestCase
@property (nonatomic, readonly) OMEMOModuleNamespace ns;
@end

@implementation OMEMOElementTests

- (void)setUp {
    [super setUp];
    // Comment this out to test legacy namespace
#define OMEMOMODULE_XMLNS_OMEMO
    
#ifdef OMEMOMODULE_XMLNS_OMEMO
    _ns = OMEMOModuleNamespaceOMEMO;
#else
    _ns = OMEMOModuleNamespaceConversationsLegacy;
#endif
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testDeviceIdSerialization {
    NSArray *deviceIds = @[@(12345), @(4223), @(31415)];
    XMPPIQ *iq = [XMPPIQ omemo_iqPublishDeviceIds:deviceIds elementId:@"announce1" xmlNamespace:self.ns];
    NSString *iqString = [iq XMLString];
    NSString *expectedString = [NSString stringWithFormat:@" \
    <iq type='set' id='announce1'> \
    <pubsub xmlns='http://jabber.org/protocol/pubsub'> \
    <publish node='%@'> \
    <item> \
    <list xmlns='%@'> \
    <device id='12345' /> \
    <device id='4223' /> \
    <device id='31415' /> \
    </list> \
    </item> \
    </publish> \
    <publish-options> \
    <x xmlns='jabber:x:data' type='submit'> \
    <field var='FORM_TYPE' type='hidden'> \
    <value>http://jabber.org/protocol/pubsub#publish-options</value> \
    </field> \
    <field var='pubsub#persist_items'> \
    <value>1</value> \
    </field> \
    <field var='pubsub#access_model'> \
    <value>open</value> \
    </field> \
    </x> \
    </publish-options> \
    </pubsub> \
    </iq> \
    ", [OMEMOModule xmlnsOMEMODeviceList:self.ns], [OMEMOModule xmlnsOMEMO:self.ns]];
    NSError *error = nil;
    NSXMLElement *outputIQ = [[NSXMLElement alloc] initWithXMLString:iqString error:&error];
    XCTAssertNil(error);
    NSXMLElement *expectedIQ = [[NSXMLElement alloc] initWithXMLString:expectedString error:&error];
    XCTAssertNil(error);
    
    XCTAssertEqualObjects([outputIQ XMLString], [expectedIQ XMLString]);
}

- (void) testPublishDeviceBundle {
    NSString *expectedString = [NSString stringWithFormat:@" \
    <iq type='set' id='announce2'> \
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
    <publish-options> \
    <x xmlns='jabber:x:data' type='submit'> \
    <field var='FORM_TYPE' type='hidden'> \
    <value>http://jabber.org/protocol/pubsub#publish-options</value> \
    </field> \
    <field var='pubsub#persist_items'> \
    <value>1</value> \
    </field> \
    <field var='pubsub#access_model'> \
    <value>open</value> \
    </field> \
    </x> \
    </publish-options> \
    </pubsub> \
    </iq> \
    ", [OMEMOModule xmlnsOMEMOBundles:self.ns], [OMEMOModule xmlnsOMEMO:self.ns]];
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
    XMPPIQ *iq = [XMPPIQ omemo_iqPublishBundle:bundle elementId:@"announce2" xmlNamespace:self.ns];
    XCTAssertEqualObjects([iq XMLStringWithOptions:NSXMLNodePrettyPrint], [expectedXML XMLStringWithOptions:NSXMLNodePrettyPrint]);
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
    NSString *expected = [NSString stringWithFormat:@" \
    <iq type='get' \
    to='juliet@capulet.lit' \
    id='fetch1'> \
    <pubsub xmlns='http://jabber.org/protocol/pubsub'> \
    <items node='%@:31415'/> \
    </pubsub> \
    </iq> \
    ", [OMEMOModule xmlnsOMEMOBundles:self.ns]];
    NSError *error = nil;
    NSXMLElement *expectedElement = [[NSXMLElement alloc] initWithXMLString:expected error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(expectedElement);
    XMPPIQ *iq = [XMPPIQ omemo_iqFetchBundleForDeviceId:31415 jid:[XMPPJID jidWithString:@"juliet@capulet.lit"] elementId:@"fetch1" xmlNamespace:self.ns];
    XCTAssertEqualObjects([iq XMLStringWithOptions:NSXMLNodePrettyPrint], [expectedElement XMLStringWithOptions:NSXMLNodePrettyPrint]);
}

/**
 <encrypted xmlns='urn:xmpp:omemo:0'>
  <header sid='27183'>
    <key rid='31415'>BASE64ENCODED...</key>
    <key prekey="true" rid='12321'>BASE64ENCODED...</key>
    <!-- ... -->
    <iv>BASE64ENCODED...</iv>
  </header>
</encrypted>
 */
- (void) testKeyTransportElement {
    NSString *expected = [NSString stringWithFormat:@" \
    <encrypted xmlns='%@'> \
    <header sid='27183'> \
    <key rid='31415'>MzE0MTU=</key> \
    <key prekey=\"true\" rid='12321'>MTIzMjE=</key> \
    <iv>aXY=</iv> \
    </header> \
    </encrypted> \
    ", [OMEMOModule xmlnsOMEMO:self.ns]];
    NSXMLElement *expectedElement = [[NSXMLElement alloc] initWithXMLString:expected error:nil];
    XCTAssertNotNil(expectedElement);
    NSString *key1 = @"MzE0MTU=";
    NSString *key2 = @"MTIzMjE=";
    NSString *iv = @"aXY=";
    NSData *keyData1 = [[NSData alloc] initWithBase64EncodedString:key1 options:0];
    NSData *keyData2 = [[NSData alloc] initWithBase64EncodedString:key2 options:0];
    NSData *ivData = [[NSData alloc] initWithBase64EncodedString:iv options:0];
    NSArray<OMEMOKeyData*> *keyData = @[[[OMEMOKeyData alloc] initWithDeviceId:31415 data:keyData1 isPreKey:NO],
                         [[OMEMOKeyData alloc] initWithDeviceId:12321 data:keyData2 isPreKey:YES]];
    uint32_t senderDeviceId = 27183;
    NSXMLElement *testElement = [NSXMLElement omemo_keyTransportElementWithKeyData:keyData iv:ivData senderDeviceId:senderDeviceId xmlNamespace:self.ns];
    
    XCTAssertTrue([expectedElement omemo_isEncryptedElement:self.ns]);
    XCTAssertTrue([testElement omemo_isEncryptedElement:self.ns]);
    
    XCTAssertTrue(senderDeviceId == [expectedElement omemo_senderDeviceId]);
    XCTAssertTrue(senderDeviceId == [testElement omemo_senderDeviceId]);
    
    NSArray<OMEMOKeyData*> *expectedElementKeyData = [expectedElement omemo_keyData];
    NSArray<OMEMOKeyData*> *testElementKeyData = [testElement omemo_keyData];
    [keyData enumerateObjectsUsingBlock:^(OMEMOKeyData * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        XCTAssertEqualObjects(obj.data, expectedElementKeyData[idx].data);
        XCTAssertEqual(obj.deviceId, expectedElementKeyData[idx].deviceId);
        XCTAssertEqual(obj.isPreKey, expectedElementKeyData[idx].isPreKey);
        XCTAssertEqualObjects(obj.data, testElementKeyData[idx].data);
        XCTAssertEqual(obj.deviceId, testElementKeyData[idx].deviceId);
        XCTAssertEqual(obj.isPreKey, testElementKeyData[idx].isPreKey);
    }];

    XCTAssertNil([expectedElement omemo_payload]);
    XCTAssertNil([testElement omemo_payload]);
    
    XCTAssertEqualObjects(ivData, [expectedElement omemo_iv]);
    XCTAssertEqualObjects(ivData, [testElement omemo_iv]);
}

/*
<iq from='juliet@capulet.lit' type='set' id='announce2'>
  <pubsub xmlns='http://jabber.org/protocol/pubsub'>
    <items node='urn:xmpp:omemo:0:bundles:31415'>
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
    </items>
  </pubsub>
</iq>
 */
- (void) testBundleParsing {
    NSString *expectedString = [NSString stringWithFormat:@" \
    <iq type='set' id='announce2'> \
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
    <publish-options> \
    <x xmlns='jabber:x:data' type='submit'> \
    <field var='FORM_TYPE' type='hidden'> \
    <value>http://jabber.org/protocol/pubsub#publish-options</value> \
    </field> \
    <field var='pubsub#persist_items'> \
    <value>1</value> \
    </field> \
    <field var='pubsub#access_model'> \
    <value>open</value> \
    </field> \
    </x> \
    </publish-options> \
    </pubsub> \
    </iq> \
    ",[OMEMOModule xmlnsOMEMOBundles:self.ns], [OMEMOModule xmlnsOMEMO:self.ns]];
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
    XMPPIQ *iq = [XMPPIQ omemo_iqPublishBundle:bundle elementId:@"announce2" xmlNamespace:self.ns];
    XCTAssertEqualObjects([iq XMLStringWithOptions:NSXMLNodePrettyPrint], [expectedXML XMLStringWithOptions:NSXMLNodePrettyPrint]);
    
    OMEMOBundle *expectedBundle = [[XMPPIQ iqFromElement:expectedXML] omemo_bundle:self.ns];
    OMEMOBundle *bundle2 = [iq omemo_bundle:self.ns];
    
    XMPPIQ *expectedIQ = [XMPPIQ omemo_iqPublishBundle:expectedBundle elementId:@"eid" xmlNamespace:self.ns];
    XMPPIQ *bundle2iq = [XMPPIQ omemo_iqPublishBundle:bundle2 elementId:@"eid" xmlNamespace:self.ns];
    
    XCTAssertEqualObjects([expectedIQ XMLStringWithOptions:NSXMLNodePrettyPrint], [bundle2iq XMLStringWithOptions:NSXMLNodePrettyPrint]);
}

- (void) testFetchDeviceList {
    NSString *expected = [NSString stringWithFormat:@" \
    <iq to='juliet@capulet.lit' type='get' id='fetch1'> \
    <pubsub xmlns='http://jabber.org/protocol/pubsub'> \
    <items node='%@'/> \
    </pubsub> \
    </iq> \
    ",[OMEMOModule xmlnsOMEMODeviceList:self.ns]];
    NSError *error = nil;
    NSXMLElement *expXml = [[NSXMLElement alloc] initWithXMLString:expected error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(expXml);
    XMPPJID *jid = [XMPPJID jidWithString:@"juliet@capulet.lit"];
    XMPPIQ *iq = [XMPPIQ omemo_iqFetchDeviceIdsForJID:jid elementId:@"fetch1" xmlNamespace:self.ns];
    XMPPIQ *expIq = [XMPPIQ iqFromElement:expXml];
    XCTAssertEqualObjects([expIq type], [iq type]);
    XCTAssertEqualObjects([expIq to], [iq to]);
    XCTAssertEqualObjects([expIq elementID], [iq elementID]);
    NSXMLElement *pubsub = [iq elementForName:@"pubsub" xmlns:XMLNS_PUBSUB];
    NSXMLElement *expPubsub = [expIq elementForName:@"pubsub" xmlns:XMLNS_PUBSUB];
    XCTAssertEqualObjects(pubsub.prettyXMLString, expPubsub.prettyXMLString);
}

@end
