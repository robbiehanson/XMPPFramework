//
//  CapabilitiesHashingTest.m
//  XMPPFrameworkTests
//
//  Created by Paul Melnikow on 4/18/15.
//  Copyright (c) 2015 Paul Melnikow. All rights reserved.
//

#import <XCTest/XCTest.h>
@import XMPPFramework;

@interface XMPPCapabilities (Private)
+ (NSString *)hashCapabilitiesFromQuery:(NSXMLElement *)query;
@end

@interface CapabilitiesHashingTest : XCTestCase
@end

@implementation CapabilitiesHashingTest

- (void)test1
{
    // From XEP-0115, Section 5.2
    
    NSMutableString *s = [NSMutableString string];
    [s appendString:@"<query xmlns='http://jabber.org/protocol/disco#info'>"];
    [s appendString:@"  <identity category='client' name='Exodus 0.9.1' type='pc'/>"];
    [s appendString:@"  <feature var='http://jabber.org/protocol/caps'/>"];
    [s appendString:@"  <feature var='http://jabber.org/protocol/disco#info'/>"];
    [s appendString:@"  <feature var='http://jabber.org/protocol/disco#items'/>"];
    [s appendString:@"  <feature var='http://jabber.org/protocol/muc'/>"];
    [s appendString:@"</query>"];
    
    NSXMLDocument *doc = [[NSXMLDocument alloc] initWithXMLString:s options:0 error:nil];
    
    NSXMLElement *query = [doc rootElement];
    
    NSString *expected = @"QgayPKawpkPSDYmwT/WM94uAlu0=";
    
    XCTAssertEqualObjects([XMPPCapabilities hashCapabilitiesFromQuery:query], expected);
}

- (void)test2
{
    // From XEP-0115, Section 5.3
    
    NSMutableString *s = [NSMutableString string];
    [s appendString:@"<query xmlns='http://jabber.org/protocol/disco#info'>"];
    [s appendString:@"  <identity xml:lang='en' category='client' name='Psi 0.11' type='pc'/>"];
    [s appendString:@"  <identity xml:lang='el' category='client' name='Ψ 0.11' type='pc'/>"];
    [s appendString:@"  <feature var='http://jabber.org/protocol/caps'/>"];
    [s appendString:@"  <feature var='http://jabber.org/protocol/disco#info'/>"];
    [s appendString:@"  <feature var='http://jabber.org/protocol/disco#items'/>"];
    [s appendString:@"  <feature var='http://jabber.org/protocol/muc'/>"];
    [s appendString:@"  <x xmlns='jabber:x:data' type='result'>"];
    [s appendString:@"    <field var='FORM_TYPE' type='hidden'>"];
    [s appendString:@"      <value>urn:xmpp:dataforms:softwareinfo</value>"];
    [s appendString:@"    </field>"];
    [s appendString:@"    <field var='ip_version'>"];
    [s appendString:@"      <value>ipv4</value>"];
    [s appendString:@"      <value>ipv6</value>"];
    [s appendString:@"    </field>"];
    [s appendString:@"    <field var='os'>"];
    [s appendString:@"      <value>Mac</value>"];
    [s appendString:@"    </field>"];
    [s appendString:@"    <field var='os_version'>"];
    [s appendString:@"      <value>10.5.1</value>"];
    [s appendString:@"    </field>"];
    [s appendString:@"    <field var='software'>"];
    [s appendString:@"      <value>Psi</value>"];
    [s appendString:@"    </field>"];
    [s appendString:@"    <field var='software_version'>"];
    [s appendString:@"      <value>0.11</value>"];
    [s appendString:@"    </field>"];
    [s appendString:@"  </x>"];
    [s appendString:@"</query>"];
    
    NSXMLDocument *doc = [[NSXMLDocument alloc] initWithXMLString:s options:0 error:nil];
    
    NSXMLElement *query = [doc rootElement];
    
    NSString *expected = @"q07IKJEyjvHSyhy//CH0CxmKi8w=";
    
    XCTAssertEqualObjects([XMPPCapabilities hashCapabilitiesFromQuery:query], expected);
}

- (void)test3
{
    NSMutableString *s = [NSMutableString string];
    [s appendString:@"<query node='http://pidgin.im/#WsE3KKs1gYLeYKAn5zQHkTkRnUA='"];
    [s appendString:@"      xmlns='http://jabber.org/protocol/disco#info'>"];
    [s appendString:@"  <identity category='client' name='Pidgin' type='pc'/>"];
    [s appendString:@"  <feature var='jabber:iq:last'/>"];
    [s appendString:@"  <feature var='jabber:iq:oob'/>"];
    [s appendString:@"  <feature var='urn:xmpp:time'/>"];
    [s appendString:@"  <feature var='jabber:iq:version'/>"];
    [s appendString:@"  <feature var='jabber:x:conference'/>"];
    [s appendString:@"  <feature var='http://jabber.org/protocol/bytestreams'/>"];
    [s appendString:@"  <feature var='http://jabber.org/protocol/caps'/>"];
    [s appendString:@"  <feature var='http://jabber.org/protocol/chatstates'/>"];
    [s appendString:@"  <feature var='http://jabber.org/protocol/disco#info'/>"];
    [s appendString:@"  <feature var='http://jabber.org/protocol/disco#items'/>"];
    [s appendString:@"  <feature var='http://jabber.org/protocol/muc'/>"];
    [s appendString:@"  <feature var='http://jabber.org/protocol/muc#user'/>"];
    [s appendString:@"  <feature var='http://jabber.org/protocol/si'/>"];
    [s appendString:@"  <feature var='http://jabber.org/protocol/si/profile/file-transfer'/>"];
    [s appendString:@"  <feature var='http://jabber.org/protocol/xhtml-im'/>"];
    [s appendString:@"  <feature var='urn:xmpp:ping'/>"];
    [s appendString:@"  <feature var='urn:xmpp:bob'/>"];
    [s appendString:@"  <feature var='urn:xmpp:jingle:1'/>"];
    [s appendString:@"  <feature var='urn:xmpp:jingle:transports:raw-udp:1'/>"];
    [s appendString:@"  <feature var='http://www.google.com/xmpp/protocol/session'/>"];
    [s appendString:@"  <feature var='http://www.google.com/xmpp/protocol/voice/v1'/>"];
    [s appendString:@"  <feature var='http://www.google.com/xmpp/protocol/video/v1'/>"];
    [s appendString:@"  <feature var='http://www.google.com/xmpp/protocol/camera/v1'/>"];
    [s appendString:@"  <feature var='urn:xmpp:jingle:apps:rtp:audio'/>"];
    [s appendString:@"  <feature var='urn:xmpp:jingle:apps:rtp:video'/>"];
    [s appendString:@"  <feature var='urn:xmpp:jingle:transports:ice-udp:1'/>"];
    [s appendString:@"  <feature var='urn:xmpp:avatar:metadata'/>"];
    [s appendString:@"  <feature var='urn:xmpp:avatar:data'/>"];
    [s appendString:@"  <feature var='urn:xmpp:avatar:metadata+notify'/>"];
    [s appendString:@"  <feature var='http://jabber.org/protocol/mood'/>"];
    [s appendString:@"  <feature var='http://jabber.org/protocol/mood+notify'/>"];
    [s appendString:@"  <feature var='http://jabber.org/protocol/tune'/>"];
    [s appendString:@"  <feature var='http://jabber.org/protocol/tune+notify'/>"];
    [s appendString:@"  <feature var='http://jabber.org/protocol/nick'/>"];
    [s appendString:@"  <feature var='http://jabber.org/protocol/nick+notify'/>"];
    [s appendString:@"  <feature var='http://jabber.org/protocol/ibb'/>"];
    [s appendString:@"</query>"];
    
    NSXMLDocument *doc = [[NSXMLDocument alloc] initWithXMLString:s options:0 error:nil];
    
    NSXMLElement *query = [doc rootElement];
    
    NSString *expected = @"WsE3KKs1gYLeYKAn5zQHkTkRnUA=";
    
    XCTAssertEqualObjects([XMPPCapabilities hashCapabilitiesFromQuery:query], expected);
}

@end
