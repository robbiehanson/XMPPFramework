//
//  OMEMOModule.m
//  Pods
//
//  Created by Chris Ballinger on 4/21/16.
//
//

#import "OMEMOModule.h"
#import "XMPPPubSub.h"
#import "XMPPIQ+XEP_0060.h"
#import "XMPPIQ+OMEMO.h"
#import "XMPPMessage+OMEMO.h"

@interface OMEMOModule()
@end

@implementation OMEMOModule

- (instancetype) initWithOMEMOStorage:(id<OMEMOStorageDelegate>)omemoStorage {
    return [self initWithOMEMOStorage:omemoStorage dispatchQueue:NULL];
}

- (instancetype) initWithDispatchQueue:(dispatch_queue_t)queue {
    return [self initWithOMEMOStorage:nil dispatchQueue:queue];
}

- (instancetype) initWithOMEMOStorage:(id<OMEMOStorageDelegate>)omemoStorage dispatchQueue:(nullable dispatch_queue_t)queue {
    if (self = [super initWithDispatchQueue:queue]) {
        if ([omemoStorage configureWithParent:self queue:moduleQueue]) {
            _omemoStorage = omemoStorage;
        }
    }
    return self;
}

- (BOOL)activate:(XMPPStream *)aXmppStream
{
    if ([super activate:aXmppStream])
    {
        [xmppStream autoAddDelegate:self delegateQueue:moduleQueue toModulesOfClass:[XMPPCapabilities class]];
        return YES;
    }
    
    return NO;
}

- (void) deactivate {
    [xmppStream removeAutoDelegate:self delegateQueue:moduleQueue fromModulesOfClass:[XMPPCapabilities class]];
    [super deactivate];
}


- (void) publishDeviceIds:(NSArray<NSNumber*>*)deviceIds {
    XMPPIQ *iq = [XMPPIQ omemo_iqForDeviceIds:deviceIds];
    [xmppStream sendElement:iq];
}


/**
 * Check for devicelist update

<message from='juliet@capulet.lit'
         to='romeo@montague.lit'
         type='headline'
         id='update_01'>
  <event xmlns='http://jabber.org/protocol/pubsub#event'>
    <items node='urn:xmpp:omemo:0:devicelist'>
      <item>
        <list xmlns='urn:xmpp:omemo:0'>
          <device id='12345' />
          <device id='4223' />
        </list>
      </item>
    </items>
  </event>
</message>
 */
- (void) processIncomingDeviceListItems:(NSXMLElement*)items originalMessage:(XMPPMessage*)message {
    NSXMLElement *item = [items elementForName:@"item"];
    NSXMLElement *list = [item elementForName:@"list" xmlns:XMLNS_OMEMO];
    NSArray<NSXMLElement*> *deviceElements = [list elementsForName:@"device"];
    NSMutableArray *deviceIds = [NSMutableArray arrayWithCapacity:deviceElements.count];
    [deviceElements enumerateObjectsUsingBlock:^(NSXMLElement *  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSNumber *deviceId = [obj attributeNumberIntegerValueForName:@"id"];
        NSParameterAssert(deviceId != nil);
        if (deviceId) {
            [deviceIds addObject:deviceId];
        }
    }];
    if (deviceIds.count > 0) {
        [multicastDelegate omemo:self deviceListUpdate:deviceIds fromJID:[message from] message:message];
    }
}

#pragma mark XMPPStreamDelegate methods

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message {
    
    // Incoming pubsub event, probably device list update
    NSXMLElement *event = [message elementForName:@"event" xmlns:XMLNS_PUBSUB_EVENT];
    if (event) {
        NSXMLElement *items = [event elementForName:@"items" xmlns:XMLNS_OMEMO_DEVICELIST];
        // Device List update
        if (items) {
            [self processIncomingDeviceListItems:items originalMessage:message];
        }
    }
    
    
}

#pragma mark XMPPCapabilitiesDelegate methods

- (NSArray<NSString*>*) myFeaturesForXMPPCapabilities:(XMPPCapabilities *)sender {
    return @[XMLNS_OMEMO_DEVICELIST, XMLNS_OMEMO_DEVICELIST_NOTIFY];
}


@end
