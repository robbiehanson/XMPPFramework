//
//  XMPPMessage+XEP_0334.m
//  Pods
//
//  Created by Chris Ballinger on 4/16/16.
//
//

#import "XMPPMessage+XEP_0334.h"
#import "NSXMLElement+XMPP.h"

#define XMLNS_STORAGE_HINTS @"urn:xmpp:hints"

static NSString * const kMessageStore = @"store";
static NSString * const kMessageNoCopy = @"no-copy";
static NSString * const kMessageNoStore = @"no-store";
static NSString * const kMessageNoPermanentStore = @"no-permanent-store";

@implementation XMPPMessage (XEP_0334)

-(void) addStorageHint:(XMPPMessageStorage)storageHint {
    NSString *storageName = [self nameForStorageHint:storageHint];
    if (!storageName.length) {
        return;
    }
    NSXMLElement *storageElement = [NSXMLElement elementWithName:storageName xmlns:XMLNS_STORAGE_HINTS];
    [self addChild:storageElement];
}

- (NSString*) nameForStorageHint:(XMPPMessageStorage)storageHint {
    NSString *storage = nil;
    switch (storageHint) {
        case XMPPMessageStorageStore:
            storage = kMessageStore;
            break;
        case XMPPMessageStorageNoCopy:
            storage = kMessageNoCopy;
            break;
        case XMPPMessageStorageNoStore:
            storage = kMessageNoStore;
            break;
        case XMPPMessageStorageNoPermanentStore:
            storage = kMessageNoPermanentStore;
            break;
        default:
            storage = @"";
            break;
    }
    return storage;
}

- (nonnull NSArray<NSValue*>*)storageHints {
    NSArray <NSXMLElement*> *elements = [self elementsForXmlns:XMLNS_STORAGE_HINTS];
    NSMutableArray <NSValue*> *boxedHints = [NSMutableArray arrayWithCapacity:elements.count];
    [elements enumerateObjectsUsingBlock:^(NSXMLElement * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        XMPPMessageStorage storageHint = XMPPMessageStorageUnknown;
        NSString *storageName = [obj name];
        if ([storageName isEqualToString:kMessageStore]) {
            storageHint = XMPPMessageStorageStore;
        } else if ([storageName isEqualToString:kMessageNoCopy]) {
            storageHint = XMPPMessageStorageNoCopy;
        } else if ([storageName isEqualToString:kMessageNoStore]) {
            storageHint = XMPPMessageStorageNoStore;
        } else if ([storageName isEqualToString:kMessageNoPermanentStore]) {
            storageHint = XMPPMessageStorageNoPermanentStore;
        }
        [boxedHints addObject:@(storageHint)];
    }];
    return boxedHints;
}



@end
