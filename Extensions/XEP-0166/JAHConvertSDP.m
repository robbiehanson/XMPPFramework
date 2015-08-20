//
//  JAHConvertSDP.m
//  JAHConvertSDP
//
//  Created by Jon Hjelle on 5/16/14.
//  Copyright (c) 2014 Jon Hjelle. All rights reserved.
//

#import "JAHConvertSDP.h"

@interface NSMutableArray (JAHConvenience)
- (id)jah_popFirstObject;
@end

@implementation NSMutableArray (JAHConvenience)

- (id)jah_popFirstObject {
    id firstObject = [self firstObject];
    if (firstObject) {
        [self removeObjectAtIndex:0];
    }
    return firstObject;
}

@end


@implementation JAHConvertSDP

+ (NSDictionary*)dictionaryForSDP:(NSString*)sdp withCreatorRole:(NSString*)creator {
    // Divide the SDP into session and media sections
    NSMutableArray* media = [[sdp componentsSeparatedByString:@"\r\nm="] mutableCopy];
    for (NSUInteger i = 1; i < [media count]; i++) {
        NSMutableString* mediaString = [NSMutableString stringWithFormat:@"m=%@", media[i]];
        if (i != [media count] - 1) {
            [mediaString appendString:@"\r\n"];
        }
        media[i] = mediaString;
    }

    NSMutableDictionary* parsed = [NSMutableDictionary dictionary];

    NSString* session = [NSString stringWithFormat:@"%@%@", [media jah_popFirstObject], @"\r\n"];

    NSMutableArray* contents = [NSMutableArray array];
    for (NSString* m in media) {
        [contents addObject:[[self class] convertSDPMediaToDictionary:m withSession:session withCreatorRole:creator]];
    }
    parsed[@"contents"] = contents;

    NSArray* sessionLines = [[self class] linesForSDP:session];
    NSArray* groupLines = [[self class] linesForPrefix:@"a=group:" mediaLines:nil sessionLines:sessionLines];
    if ([groupLines count]) {
        parsed[@"groups"] = [[self class] groupsForGroupLines:groupLines];
    }

    return parsed;
}

+ (NSDictionary*)convertSDPMediaToDictionary:(NSString *)media withSession:(NSString*)session withCreatorRole:(NSString *)creator {
    NSMutableDictionary* content = [NSMutableDictionary dictionary];
    content[@"creator"] = creator;

    NSArray* mediaLines = [[self class] linesForSDP:media];
    NSArray* sessionLines = [[self class] linesForSDP:session];
    NSDictionary* mLine = [[self class] mLineForLine:[mediaLines firstObject]];

    NSString* name = mLine[@"media"];
    // If we have a mid, use that for the content name instead
    NSString* mid = [[self class] lineForPrefix:@"a=mid:" mediaLines:mediaLines sessionLines:nil];
    if (mid) {
        name = [mid substringFromIndex:6];
    }
    content[@"name"] = name;

    NSString* senders;
    if ([[self class] lineForPrefix:@"a=sendrecv" mediaLines:mediaLines sessionLines:sessionLines]) {
        senders = @"both";
    } else if ([[self class] lineForPrefix:@"a=sendonly" mediaLines:mediaLines sessionLines:sessionLines]) {
        senders = @"initiator";
    } else if ([[self class] lineForPrefix:@"a=recvonly" mediaLines:mediaLines sessionLines:sessionLines]) {
        senders = @"responder";
    } else if ([[self class] lineForPrefix:@"a=inactive" mediaLines:mediaLines sessionLines:sessionLines]) {
        senders = @"none";
    }
    content[@"senders"] = senders;

    NSMutableDictionary* description = [NSMutableDictionary dictionary];

    NSMutableDictionary* transport = [NSMutableDictionary dictionary];
    if ([mLine[@"media"] isEqualToString:@"application"]) {
        description[@"descType"] = @"datachannel";

        NSMutableArray* sctp = [NSMutableArray array];
        transport[@"sctp"] = sctp;
    } else {
        description[@"descType"] = @"rtp";
        description[@"media"] = mLine[@"media"];
        description[@"payloads"] = [NSMutableArray array];
        description[@"encryption"] = [NSMutableArray array];
        description[@"feedback"] = [NSMutableArray array];
        description[@"headerExtensions"] = [NSMutableArray array];

        transport[@"transType"] = @"iceUdp";
        transport[@"candidates"] = [NSMutableArray array];
        transport[@"fingerprints"] = [NSMutableArray array];

        NSString* ssrc = [[self class] lineForPrefix:@"a=ssrc:" mediaLines:mediaLines sessionLines:nil];
        if (ssrc) {
            ssrc = [[[ssrc substringFromIndex:7] componentsSeparatedByString:@" "] firstObject];
            description[@"ssrc"] = ssrc;
        }

        NSArray* rtpMapLines = [[self class] linesForPrefix:@"a=rtpmap:" mediaLines:mediaLines sessionLines:nil];
        for (NSString* line in rtpMapLines) {
            NSMutableDictionary* payload = [[self class] rtpMapForLine:line];
            payload[@"feedback"] = [NSMutableArray array];

            NSArray* fmtpLines = [[self class] linesForPrefix:[NSString stringWithFormat:@"a=fmtp:%@", payload[@"id"]] mediaLines:mediaLines sessionLines:nil];
            for (NSString* line in fmtpLines) {
                payload[@"parameters"] = [[self class] fmtpForLine:line];
            }

            NSArray* fbLines = [[self class] linesForPrefix:[NSString stringWithFormat:@"a=rtcp-fb:%@", payload[@"id"]] mediaLines:mediaLines sessionLines:nil];
            for (NSString* line in fbLines) {
                [payload[@"feedback"] addObject:[[self class] rtcpfbForLine:line]];
            }

            [description[@"payloads"] addObject:payload];
        }

        NSArray* cryptoLines = [[self class] linesForPrefix:@"a=crypto:" mediaLines:mediaLines sessionLines:sessionLines];
        for (NSString* line in cryptoLines) {
            [description[@"encryption"] addObject:[[self class] cryptoForLine:line]];
        }

        if ([[self class] linesForPrefix:@"a=rtcp-mux" mediaLines:mediaLines sessionLines:nil]) {
            description[@"mux"] = @YES;
        }

        NSArray* fbLines = [[self class] linesForPrefix:@"a=rtcp-fb:*" mediaLines:mediaLines sessionLines:nil];
        for (NSString* line in fbLines) {
            [description[@"feedback"] addObject:[[self class] rtcpfbForLine:line]];
        }

        NSArray* extLines = [[self class] linesForPrefix:@"a=extmap:" mediaLines:mediaLines sessionLines:nil];
        for (NSString* line in extLines) {
            NSMutableDictionary* ext = [[self class] extMapForLine:line];

            NSDictionary* senders = @{@"sendonly": @"responder",
                                      @"recvonly": @"initiator",
                                      @"sendrecv": @"both",
                                      @"inactive": @"none"};
            ext[@"senders"] = senders[ext[@"senders"]];

            [description[@"headerExtensions"] addObject:ext];
        }

        NSArray* ssrcGroupLines = [[self class] linesForPrefix:@"a=ssrc-group" mediaLines:mediaLines sessionLines:nil];
        description[@"sourceGroups"] = [[self class] sourceGroupsForGroupLines:ssrcGroupLines];

        NSArray* ssrcLines = [[self class] linesForPrefix:@"a=ssrc:" mediaLines:mediaLines sessionLines:nil];
        description[@"sources"] = [[self class] sourcesForLines:ssrcLines];
    }

    // transport specific attributes
    NSArray* fingerprintLines = [[self class] linesForPrefix:@"a=fingerprint:" mediaLines:mediaLines sessionLines:sessionLines];
    for (NSString* line in fingerprintLines) {
        NSMutableDictionary* fp = [[self class] fingerprintForLine:line];
        NSString* setup = [[self class] lineForPrefix:@"a=setup:" mediaLines:mediaLines sessionLines:sessionLines];
        if (setup) {
            fp[@"setup"] = [setup substringFromIndex:8];
        }
        [transport[@"fingerprints"] addObject:fp];
    }

    NSString* ufragLine = [[self class] lineForPrefix:@"a=ice-ufrag:" mediaLines:mediaLines sessionLines:sessionLines];
    NSString* pwdLine = [[self class] lineForPrefix:@"a=ice-pwd:" mediaLines:mediaLines sessionLines:sessionLines];
    if (ufragLine && pwdLine) {
        transport[@"ufrag"] = [ufragLine substringFromIndex:12];
        transport[@"pwd"] = [pwdLine substringFromIndex:10];
        transport[@"candidates"] = [NSMutableArray array];

        NSArray* candidateLines = [[self class] linesForPrefix:@"a=candidate:" mediaLines:mediaLines sessionLines:sessionLines];
        for (NSString* line in candidateLines) {
            [transport[@"candidates"] addObject:[[self class] candidateForLine:line]];
        }
    }

    if ([description[@"descType"] isEqualToString:@"datachannel"]) {
        NSArray* sctpMapLines = [[self class] linesForPrefix:@"a=sctpmap:" mediaLines:mediaLines sessionLines:nil];
        for (NSString* line in sctpMapLines) {
            [transport[@"sctp"] addObject:[[self class] sctpMapForLine:line]];
        }
    }

    content[@"description"] = description;
    content[@"transport"] = transport;

    return content;
}

+ (NSDictionary*)candidateForLine:(NSString*)line {
    line = [[line componentsSeparatedByString:@"\r\n"] firstObject];

    NSArray* parts = [[line substringFromIndex:12] componentsSeparatedByString:@" "];

    NSMutableDictionary* candidate = [NSMutableDictionary dictionary];
    candidate[@"foundation"] = parts[0];
    candidate[@"component"] = parts[1];
    candidate[@"protocol"] = [parts[2] lowercaseString];
    candidate[@"priority"] = parts[3];
    candidate[@"ip"] = parts[4];
    candidate[@"port"] = parts[5];
    // skip parts[6] == 'typ';
    candidate[@"type"] = parts[7];
    candidate[@"generation"] = @"0";

    for (NSUInteger i = 8; i < [parts count]; i += 2) {
        if ([parts[i] isEqualToString:@"raddr"]) {
            candidate[@"relAddr"] = parts[i + 1];
        } else if ([parts[i] isEqualToString:@"rport"]) {
            candidate[@"relPort"] = parts[i + 1];
        } else if ([parts[i] isEqualToString:@"generation"]) {
            candidate[@"generation"] = parts[i + 1];
        }
    }

    candidate[@"network"] = @"1";

    candidate[@"id"] = [[NSUUID UUID] UUIDString];
    return candidate;
}

#pragma mark - Parsing stuff

+ (NSArray*)linesForSDP:(NSString*)sdp {
    NSArray* lines = [sdp componentsSeparatedByString:@"\r\n"];
    NSPredicate* predicate = [NSPredicate predicateWithFormat:@"length > 0"];
    return [lines filteredArrayUsingPredicate:predicate];
}

+ (NSString*)lineForPrefix:(NSString*)prefix mediaLines:(NSArray*)mediaLines sessionLines:(NSArray*)sessionLines {
    for (NSString* mediaLine in mediaLines) {
        if ([mediaLine hasPrefix:prefix]) {
            return mediaLine;
        }
    }

    for (NSString* sessionLine in sessionLines) {
        if ([sessionLine hasPrefix:prefix]) {
            return sessionLine;
        }
    }
    return nil;
}

+ (NSArray*)linesForPrefix:(NSString*)prefix mediaLines:(NSArray*)mediaLines sessionLines:(NSArray*)sessionLines {
    NSMutableArray* results = [NSMutableArray array];

    for (NSString* mediaLine in mediaLines) {
        if ([mediaLine hasPrefix:prefix]) {
            [results addObject:mediaLine];
        }
    }

    if ([results count]) {
        return results;
    }

    for (NSString* sessionLine in sessionLines) {
        if ([sessionLine hasPrefix:prefix]) {
            [results addObject:sessionLine];
        }
    }
    return results;
}

+ (NSArray*)groupsForGroupLines:(NSArray*)lines {
    // http://tools.ietf.org/html/rfc5888
    NSMutableArray* parsed = [NSMutableArray array];
    NSMutableArray* parts;
    for (NSString* line in lines) {
        parts = [[[line substringFromIndex:8] componentsSeparatedByString:@" "] mutableCopy];
        NSDictionary* group = @{@"semantics":[parts jah_popFirstObject],
                                @"contents": parts};
        [parsed addObject:[group mutableCopy]];
    }
    return parsed;
}

#pragma mark -

+ (NSDictionary*)mLineForLine:(NSString*)line {
    NSArray* parts = [[line substringFromIndex:2] componentsSeparatedByString:@" "];
    NSDictionary* parsed = @{@"media": parts[0],
                             @"port": parts[1],
                             @"proto": parts[2],
                             @"formats": [NSMutableArray array]};

    for (NSUInteger i = 3; i < [parts count]; i++) {
        if (parts[i]) {
            [parsed[@"format"] addObject:parts[i]];
        }
    }

    return parsed;
}

+ (NSMutableDictionary*)rtpMapForLine:(NSString*)line {
    NSMutableArray* parts = [[[line substringFromIndex:9] componentsSeparatedByString:@" "] mutableCopy];
    NSMutableDictionary* parsed = [NSMutableDictionary dictionary];
    parsed[@"id"] = [parts jah_popFirstObject];

    parts = [[parts[0] componentsSeparatedByString:@"/"] mutableCopy];

    parsed[@"name"] = parts[0];
    parsed[@"clockrate"] = parts[1];
    parsed[@"channels"] = ([parts count] == 3 ? parts[2] : @"1");
    return parsed;
}

+ (NSDictionary*)sctpMapForLine:(NSString*)line {
    // based on -05 draft
    NSArray* parts = [[line substringFromIndex:10] componentsSeparatedByString:@" "];
    NSMutableDictionary* parsed = [NSMutableDictionary dictionary];
    parsed[@"number"] = parts[0];
    parsed[@"protocol"] = parts[1];
    parsed[@"streams"] = parts[2];
    return parsed;
}

+ (NSArray*)fmtpForLine:(NSString*)line {
    NSRange range = [line rangeOfString:@" "];
    NSArray* parts = [[line substringFromIndex:(range.location + 1)] componentsSeparatedByString:@";"];

    NSArray* keyValue;
    NSMutableArray* parsed = [NSMutableArray array];
    for (NSString* part in parts) {
        keyValue = [part componentsSeparatedByString:@"="];
        NSString* key = [keyValue[0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSString* value = keyValue[1];
        if (key && value) {
            [parsed addObject:@{@"key": key, @"value": value}];
        } else if (key) {
            [parsed addObject:@{@"key": @"", @"value": value}];
        }
    }

    return parsed;
}

+ (NSDictionary*)cryptoForLine:(NSString*)line {
    NSArray* parts = [[line substringFromIndex:9] componentsSeparatedByString:@" "];
    NSArray* subarray = [parts subarrayWithRange:NSMakeRange(3, [parts count] - 3)];
    NSDictionary* parsed = @{@"tag": parts[0],
                             @"cipherSuite": parts[1],
                             @"keyParams": parts[2],
                             @"sessionParams": [subarray componentsJoinedByString:@" "]};
    return parsed;
}

+ (NSMutableDictionary*)fingerprintForLine:(NSString*)line {
    NSArray* parts = [[line substringFromIndex:14] componentsSeparatedByString:@" "];
    NSMutableDictionary* parsed = [NSMutableDictionary dictionary];
    parsed[@"hash"] = parts[0];
    parsed[@"value"] = parts[1];
    return parsed;
}

+ (NSMutableDictionary*)extMapForLine:(NSString*)line {
    NSMutableArray* parts = [[[line substringFromIndex:9] componentsSeparatedByString:@" "] mutableCopy];
    NSMutableDictionary* parsed = [NSMutableDictionary dictionary];

    NSString* idPart = [parts jah_popFirstObject];
    NSRange sp = [idPart rangeOfString:@"/"];
    if (sp.location != NSNotFound) {
        parsed[@"id"] = [idPart substringWithRange:NSMakeRange(0, sp.location)];
        parsed[@"senders"] = [idPart substringFromIndex:(sp.location + 1)];
    } else {
        parsed[@"id"] = idPart;
        parsed[@"senders"] = @"sendrecv";
    }

    parsed[@"uri"] = [parts jah_popFirstObject] ?: @"";

    return parsed;
}

+ (NSDictionary*)rtcpfbForLine:(NSString*)line {
    NSMutableArray* parts = [[[line substringFromIndex:10] componentsSeparatedByString:@" "] mutableCopy];
    NSMutableDictionary* parsed = [NSMutableDictionary dictionary];
    parsed[@"id"] = [parts jah_popFirstObject];
    parsed[@"type"] = [parts jah_popFirstObject];
    if ([parsed[@"type"] isEqualToString:@"trr-int"]) {
        parsed[@"value"] = [parts jah_popFirstObject];
    } else {
        NSString* subtype = [parts jah_popFirstObject];
        parsed[@"subtype"] = [subtype length] ? subtype : @"";
    }

    parsed[@"parameters"] = parts;
    return parsed;
}

+ (NSArray*)sourceGroupsForGroupLines:(NSArray*)lines {
    NSMutableArray* parsed = [NSMutableArray array];
    NSMutableArray* parts;
    for (NSString* line in lines) {
        parts = [[[line substringFromIndex:13] componentsSeparatedByString:@" "] mutableCopy];
        [parsed addObject:@{@"semantics": [parts jah_popFirstObject],
                            @"sources": parts}];
    }
    return parsed;
}

+ (NSArray*)sourcesForLines:(NSArray*)lines {
    // http://tools.ietf.org/html/rfc5576
    NSMutableArray* parsed = [NSMutableArray array];
    NSMutableDictionary* sources = [NSMutableDictionary dictionary];

    for (NSString* line in lines) {
        NSMutableArray* parts = [[[line substringFromIndex:7] componentsSeparatedByString:@" "] mutableCopy];
        NSString* ssrc = [parts jah_popFirstObject];

        if (!sources[ssrc]) {
            NSDictionary* source = @{@"ssrc": ssrc, @"parameters": [NSMutableArray array]};
            [parsed addObject:source];

            // Keep an index
            sources[ssrc] = source;
        }

        parts = [[[parts componentsJoinedByString:@" "] componentsSeparatedByString:@":"] mutableCopy];
        NSString* attribute = [parts jah_popFirstObject];
        NSString* value = [parts componentsJoinedByString:@":"] ?: @"";

        [sources[ssrc][@"parameters"] addObject:@{@"key": attribute,
                                                  @"value": value}];
    }

    return parsed;
}

#pragma mark - Objects -> SDP

+ (NSDictionary*)senders {
    return @{@"initiator": @"sendonly",
             @"responder": @"recvonly",
             @"both": @"sendrecv",
             @"none": @"inactive",
             @"sendonly": @"initiator",
             @"recvonly": @"responder",
             @"sendrecv": @"both",
             @"inactive": @"none"};
}

+ (NSString*)SDPForSession:(NSDictionary*)session sid:(NSString*)sid time:(NSString*)time {
    if (!sid) {
        sid = session[@"sid"];
    }
    if (!sid) {
        sid = [NSString stringWithFormat:@"%f", [[NSDate date] timeIntervalSince1970] * 10];
    }
    if (!time) {
        time = [NSString stringWithFormat:@"%f", [[NSDate date] timeIntervalSince1970] * 10];
    }
    NSString* format = [NSString stringWithFormat:@"o=- %@ %@ IN IP4 0.0.0.0", sid, time];

    NSMutableArray* sdp = [NSMutableArray array];
    [sdp addObject:@"v=0"];
    [sdp addObject:format];
    [sdp addObject:@"s=-"];
    [sdp addObject:@"t=0 0"];

    for (NSDictionary* group in session[@"groups"]) {
        [sdp addObject:[NSString stringWithFormat:@"a=group:%@ %@", group[@"semantics"], [group[@"contents"] componentsJoinedByString:@" "]]];
    }

    for (NSDictionary* content in session[@"contents"]) {
        [sdp addObject:[[self class] mediaSDPForContent:content]];
    }

    return [[sdp componentsJoinedByString:@"\r\n"] stringByAppendingString:@"\r\n"];
}

+ (NSString*)mediaSDPForContent:(NSDictionary*)content {
    NSMutableArray* sdp = [NSMutableArray array];

    NSDictionary* desc = content[@"description"];
    NSDictionary* transport = content[@"transport"];

    NSMutableArray* mline = [NSMutableArray array];
    if ([desc[@"descType"] isEqualToString:@"datachannel"]) {
        [mline addObject:@"application"];
        [mline addObject:@"1"];
        [mline addObject:@"DTLS/SCTP"];
        for (NSDictionary* map in transport[@"sctp"]) {
            [mline addObject:map[@"number"]];
        }
    } else {
        [mline addObject:desc[@"media"]];
        [mline addObject:@"1"];
        if (([desc[@"encryption"] count] > 0) || ([transport[@"fingerprints"] count] > 0)) {
            [mline addObject:@"RTP/SAVPF"];
        } else {
            [mline addObject:@"RTP/AVPF"];
        }
        for (NSDictionary* payload in desc[@"payloads"]) {
            [mline addObject:payload[@"id"]];
        }
    }

    [sdp addObject:[NSString stringWithFormat:@"m=%@", [mline componentsJoinedByString:@" "]]];

    [sdp addObject:@"c=IN IP4 0.0.0.0"];

    if ([desc[@"descType"] isEqualToString:@"rtp"]) {
        [sdp addObject:@"a=rtcp:1 IN IP4 0.0.0.0"];
    }

    if (transport) {
        if (transport[@"ufrag"]) {
            [sdp addObject:[NSString stringWithFormat:@"a=ice-ufrag:%@", transport[@"ufrag"]]];
        }
        if (transport[@"pwd"]) {
            [sdp addObject:[NSString stringWithFormat:@"a=ice-pwd:%@", transport[@"pwd"]]];
        }
        if (transport[@"setup"]) {
            [sdp addObject:[NSString stringWithFormat:@"a=setup:%@", transport[@"setup"]]];
        }
        for (NSDictionary* fingerprint in transport[@"fingerprints"]) {
            [sdp addObject:[NSString stringWithFormat:@"a=fingerprint:%@ %@", fingerprint[@"hash"], fingerprint[@"value"]]];
        }
        for (NSDictionary* map in transport[@"sctp"]) {
            [sdp addObject:[NSString stringWithFormat:@"a=sctpmap:%@ %@ %@", map[@"number"], map[@"protocol"], map[@"streams"]]];
        }
    }

    if ([desc[@"descType"] isEqualToString:@"rtp"]) {
        NSString* sender = [[[self class] senders] objectForKey:content[@"senders"]] ?: @"sendrecv";
        [sdp addObject:[NSString stringWithFormat:@"a=%@", sender]];
    }
    [sdp addObject:[NSString stringWithFormat:@"a=mid:%@", content[@"name"]]];

    if (desc[@"mux"]) {
        [sdp addObject:@"a=rtcp-mux"];
    }

    for (NSDictionary* crypto in desc[@"encryption"]) {
        NSString* params = [crypto[@"sessionParams"] length] ? [NSString stringWithFormat:@" %@", crypto[@"sessionsParams"]] : @"";
        [sdp addObject:[NSString stringWithFormat:@"a=crypto:%@ %@ %@%@", crypto[@"tag"], crypto[@"cipherSuite"], crypto[@"keyParams"], params]];
    }

    for (NSDictionary* payload in desc[@"payloads"]) {
        NSString* rtpMap = [NSString stringWithFormat:@"a=rtpmap:%@ %@/%@", payload[@"id"], payload[@"name"], payload[@"clockrate"]];
        if (![payload[@"channels"] isEqualToString:@"1"]) {
            rtpMap = [rtpMap stringByAppendingFormat:@"/%@", payload[@"channels"]];
        }
        [sdp addObject:rtpMap];

        if ([payload[@"parameters"] count]) {
            NSMutableArray* fmtp = [NSMutableArray array];
            [fmtp addObject:[@"a=fmtp:" stringByAppendingString:payload[@"id"]]];
            for (NSDictionary* param in payload[@"parameters"]) {
                NSString* key = param[@"key"] ? [param[@"key"] stringByAppendingString:@"="] : @"";
                [fmtp addObject:[key stringByAppendingString:param[@"value"]]];
            }
            [sdp addObject:[fmtp componentsJoinedByString:@" "]];
        }

        if (payload[@"feedback"]) {
            for (NSDictionary* fb in payload[@"feedback"]) {
                NSMutableString* rtcp = [NSMutableString stringWithFormat:@"a=rtcp-fb:%@", payload[@"id"]];
                if ([fb[@"type"] isEqualToString:@"trr-int"]) {
                    [rtcp appendFormat:@" %@", fb[@"value"] ?: @"0"];
                } else {
                    [rtcp appendFormat:@" %@%@", fb[@"type"], [fb[@"subtype"] length] ? [@" " stringByAppendingString:fb[@"subtype"]] : @""];

                }
                [sdp addObject:rtcp];
            }
        }
    }

    for (id fb in desc[@"feedback"]) {
        NSMutableString* rtcp = [NSMutableString stringWithString:@"a=rtcp-fb:* "];
        if ([fb[@"type"] isEqualToString:@"trr-int"]) {
            [rtcp appendFormat:@"trr-int %@", fb[@"value"] ?: @"0"];
        } else {
            [rtcp appendFormat:@"%@%@", fb[@"type"], [fb[@"subtype"] length] ? [@" " stringByAppendingString:fb[@"subtype"]] : @""];
        }
        [sdp addObject:rtcp];
    }

    for (NSDictionary* hdr in desc[@"headerExtensions"]) {
        NSMutableString* extMap = [NSMutableString stringWithFormat:@"a=extmap:%@%@ %@", hdr[@"id"], hdr[@"senders"] ? [@"/" stringByAppendingString:[[[self class] senders] objectForKey:hdr[@"senders"]]] : @"", hdr[@"uri"]];
        [sdp addObject:extMap];
    }

    for (NSDictionary* ssrcGroup in desc[@"sourceGroups"]) {
        NSMutableString* group = [NSMutableString stringWithFormat:@"a=ssrc-group:%@ %@", ssrcGroup[@"semantics"], [ssrcGroup[@"sources"] componentsJoinedByString:@" "]];
        [sdp addObject:group];
    }

    for (NSDictionary* ssrc in desc[@"sources"]) {
        for (id parameter in ssrc[@"parameters"]) {
            NSMutableString* ssrcString = [NSMutableString stringWithFormat:@"a=ssrc:%@ %@%@", ssrc[@"ssrc"] ?: desc[@"ssrc"], parameter[@"key"], parameter[@"value"] ? [@":" stringByAppendingString:parameter[@"value"]] : @""];
            [sdp addObject:ssrcString];
        }
    }

    for (NSDictionary* candidate in transport[@"candidates"]) {
        [sdp addObject:[[self class] sdpForCandidate:candidate]];
    }

    return [sdp componentsJoinedByString:@"\r\n"];
}

+ (NSString*)sdpForCandidate:(NSDictionary*)candidate {
    NSMutableArray* sdp = [NSMutableArray array];

    [sdp addObject:candidate[@"foundation"]];
    [sdp addObject:candidate[@"component"]];
    [sdp addObject:[candidate[@"protocol"] uppercaseString]];
    [sdp addObject:candidate[@"priority"]];
    [sdp addObject:candidate[@"ip"]];
    [sdp addObject:candidate[@"port"]];

    NSString* type = candidate[@"type"];
    [sdp addObject:@"typ"];
    [sdp addObject:type];
    if ([type isEqualToString:@"srflx"] || [type isEqualToString:@"prflx"] || [type isEqualToString:@"relay"]) {
        if (candidate[@"relAddr"] && candidate[@"relPort"]) {
            [sdp addObject:@"raddr"];
            [sdp addObject:candidate[@"relAddr"]];
            [sdp addObject:@"rport"];
            [sdp addObject:candidate[@"relPort"]];
        }
    }

    [sdp addObject:@"generation"];
    [sdp addObject:candidate[@"generation"] ?: @"0"];

    return [@"a=candidate:" stringByAppendingString:[sdp componentsJoinedByString:@" "]];
}

@end
