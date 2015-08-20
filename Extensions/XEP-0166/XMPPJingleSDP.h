//
//  XMPPJingleSDP.h
//  xfinity-webrtc-sdk
//
//  Created by Ganvir, Manish  on 2/6/15.
//

#ifndef xfinity_webrtc_sdk_XMPPJingleSDP_h
#define xfinity_webrtc_sdk_XMPPJingleSDP_h
#import <Foundation/Foundation.h>
#import "XMPP.h"
#import "XMPPFramework.h"

// Namespace for jingle messages
#define XEP_0166_XMLNS @"urn:xmpp:jingle:1"

@interface XMPPJingleSDPUtil : NSObject
{
    NSMutableArray* session;
    NSMutableArray* media;
    NSXMLElement *transElement1;
    NSXMLElement *fprElement1;
    
    NSString *gUfrag;
    NSString *gPwd;
}
- (XMPPIQ *)SDPToXMPP:(NSString *)sdp action:(NSString *)action initiator:(XMPPJID *)initiator target:(XMPPJID *)target UID:(NSString *)UID SID:(NSString *)SID;
- (XMPPIQ *)CandidateToXMPP:(NSDictionary *)dict action:(NSString *)action initiator:(XMPPJID *)initiator target:(XMPPJID *)target UID:(NSString *)UID SID:(NSString *)SID;
- (NSXMLElement *)MediaToXMPP:(NSString *)type  data:(NSDictionary *)data target:(XMPPJID *)target UID:(NSString *)UID SID:(NSString *)SID;

- (NSString *)XMPPToSDP:(XMPPIQ *)iq;
- (NSDictionary *)XMPPToCandidate:(XMPPIQ *)iq;

- (NSString*)find_line:(NSString*)haystack  needle:(NSString*)needle;
- (NSArray*)find_lines:(NSString*)haystack  needle:(NSString*)needle;
- (NSArray*) parse_mline:(NSString*)line;

- (void) splitSDP:(NSString*)sdp;

@end

#endif
