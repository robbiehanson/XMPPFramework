//
//  XMPPIQ+LastActivityTest.m
//  XMPPFramework-Tests-Mac
//
//  Created by Daniel Rodríguez Troitiño on 02/02/13.
//  Copyright (c) 2013 XMPPFramework. All rights reserved.
//

#import <GHUnit/GHUnit.h>
#import <OCMock/OCMock.h>

#import "XMPPFramework.h"

@interface XMPPIQ_LastActivityTest : GHTestCase

@end


@implementation XMPPIQ_LastActivityTest

- (void)testLastActivityQueryTo
{
    XMPPJID *jid = [XMPPJID jidWithString:@"romeo@montague.net/orchard"];

    XMPPIQ *iq = [XMPPIQ lastActivityQueryTo:jid];

    GHAssertEqualStrings(iq.type, @"get", nil);
    GHAssertEqualObjects(iq.to, jid, nil);
    GHAssertNotNil([iq attributeStringValueForName:@"id"], nil);
    GHAssertNotNil([iq elementForName:@"query" xmlns:XMPPLastActivityNamespace], nil);
}

- (void)testLastActivityResponseToWithSeconds
{
    XMPPJID *romeo = [XMPPJID jidWithString:@"romeo@montague.net/orchard"];
    XMPPJID *juliet = [XMPPJID jidWithString:@"juliet@capulet.com/balcony"];
    XMPPIQ *request = [XMPPIQ lastActivityQueryTo:romeo];
    [request setAttributesAsDictionary:@{@"from": [juliet full]}];

    XMPPIQ *response = [XMPPIQ lastActivityResponseTo:request withSeconds:23U];

    GHAssertEqualStrings(response.type, @"result", nil);
    GHAssertEqualObjects(response.to, juliet, nil);
    GHAssertEqualStrings(response.elementID, request.elementID, nil);

    NSXMLElement *query = [response elementForName:@"query" xmlns:XMPPLastActivityNamespace];
    GHAssertNotNil(query, nil);
    GHAssertEquals([query attributeUnsignedIntegerValueForName:@"seconds"], (NSUInteger) 23, nil);
    GHAssertEqualStrings([query stringValue], @"", @"stringValue should be an empty string");
}

- (void)testLastActivityResponseToWithSecondsStatus
{
    XMPPJID *romeo = [XMPPJID jidWithString:@"romeo@montague.net/orchard"];
    XMPPJID *juliet = [XMPPJID jidWithString:@"juliet@capulet.com/balcony"];
    XMPPIQ *request = [XMPPIQ lastActivityQueryTo:romeo];
    [request setAttributesAsDictionary:@{@"from": [juliet full]}];

    XMPPIQ *response = [XMPPIQ lastActivityResponseTo:request withSeconds:37U status:@"Heading Home"];

    GHAssertEqualStrings(response.type, @"result", nil);
    GHAssertEqualObjects(response.to, juliet, nil);
    GHAssertEqualStrings(response.elementID, request.elementID, nil);

    NSXMLElement *query = [response elementForName:@"query" xmlns:XMPPLastActivityNamespace];
    GHAssertNotNil(query, nil);
    GHAssertEquals([query attributeUnsignedIntegerValueForName:@"seconds"], (NSUInteger) 37, nil);
    GHAssertEqualStrings([query stringValue], @"Heading Home", nil);
}

- (void)testLastActivityResponseForbiddenTo
{
    XMPPJID *romeo = [XMPPJID jidWithString:@"romeo@montague.net/orchard"];
    XMPPJID *juliet = [XMPPJID jidWithString:@"juliet@capulet.com/balcony"];
    XMPPIQ *request = [XMPPIQ lastActivityQueryTo:romeo];
    [request setAttributesAsDictionary:@{@"from": [juliet full]}];

    XMPPIQ *response = [XMPPIQ lastActivityResponseForbiddenTo:request];

    GHAssertEqualStrings(response.type, @"error", nil);
    GHAssertEqualObjects(response.to, juliet, nil);
    GHAssertEqualStrings(response.elementID, request.elementID, nil);

    NSXMLElement *error = [response elementForName:@"error"];
    GHAssertNotNil(error, nil);
    GHAssertEqualStrings([error attributeStringValueForName:@"type"], @"auth", nil);

    NSXMLElement *reason = [error elementForName:@"forbidden" xmlns:@"urn:ietf:params:xml:ns:xmpp-stanzas"];
    GHAssertNotNil(reason, nil);
}

- (void)testIsLastActivity
{
    XMPPJID *romeo = [XMPPJID jidWithString:@"romeo@montague.net/orchard"];
    XMPPJID *juliet = [XMPPJID jidWithString:@"juliet@capulet.com/balcony"];
    XMPPIQ *request = [XMPPIQ lastActivityQueryTo:romeo];
    [request setAttributesAsDictionary:@{@"from": [juliet full]}];
    XMPPIQ *response = [XMPPIQ lastActivityResponseTo:request withSeconds:43U];

    GHAssertTrue([request isLastActivityQuery], nil);
    GHAssertTrue([response isLastActivityQuery], nil);
}

- (void)testLastActivitySeconds
{
    XMPPJID *romeo = [XMPPJID jidWithString:@"romeo@montague.net/orchard"];
    XMPPJID *juliet = [XMPPJID jidWithString:@"juliet@capulet.com/balcony"];
    XMPPIQ *request = [XMPPIQ lastActivityQueryTo:romeo];
    [request setAttributesAsDictionary:@{@"from": [juliet full]}];
    XMPPIQ *response = [XMPPIQ lastActivityResponseTo:request withSeconds:57U];

    GHAssertEquals([response lastActivitySeconds], (NSUInteger) 57, nil);
}

- (void)testLastActivityUnavailableStatus
{
    XMPPJID *romeo = [XMPPJID jidWithString:@"romeo@montague.net/orchard"];
    XMPPJID *juliet = [XMPPJID jidWithString:@"juliet@capulet.com/balcony"];
    XMPPIQ *request = [XMPPIQ lastActivityQueryTo:romeo];
    [request setAttributesAsDictionary:@{@"from": [juliet full]}];
    XMPPIQ *response = [XMPPIQ lastActivityResponseTo:request withSeconds:57U status:@"Heading Home"];

    GHAssertEqualStrings([response lastActivityUnavailableStatus], @"Heading Home", nil);
}

@end
