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

-(void) setStorageHint:(XMPPMessageStorage)storageHint {
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
        default:
            storage = @"";
            break;
    }
    return storage;
}

- (XMPPMessageStorage) storageHint {
    NSArray <NSXMLElement*> *elements = [self elementsForXmlns:XMLNS_STORAGE_HINTS];
    NSXMLElement *storageElement = elements.firstObject;
    if (!storageElement) {
        return XMPPMessageStorageUndefined;
    }
    NSString *storageName = [storageElement name];
    if (!storageName) {
        return XMPPMessageStorageUndefined;
    }
    XMPPMessageStorage storageHint = XMPPMessageStorageUndefined;
    if ([storageName isEqualToString:kMessageStore]) {
        storageHint = XMPPMessageStorageStore;
    } else if ([storageName isEqualToString:kMessageNoCopy]) {
        storageHint = XMPPMessageStorageNoCopy;
    } else if ([storageName isEqualToString:kMessageNoStore]) {
        storageHint = XMPPMessageStorageNoStore;
    } else if ([storageName isEqualToString:kMessageNoPermanentStore]) {
        storageHint = XMPPMessageStorageNoPermanentStore;
    }
    return storageHint;
}



@end
