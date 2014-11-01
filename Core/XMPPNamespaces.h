//
// Created by Jonathon Staff on 10/22/14.
// Copyright (c) 2014 nplexity, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
* This class is provided to house various namespaces that are reused throughout
* the project. Feel free to add to the constants as you see necessary. If a
* particular namespace is only applicable to a particular extension, then it
* should be inside that extension rather than here.
*/

extern NSString *const XMPPSINamespace;
extern NSString *const XMPPSIProfileFileTransferNamespace;
extern NSString *const XMPPFeatureNegNamespace;
extern NSString *const XMPPBytestreamsNamespace;
extern NSString *const XMPPIBBNamespace;
extern NSString *const XMPPDiscoItemsNamespace;
extern NSString *const XMPPDiscoInfoNamespace;

@interface XMPPNamespaces : NSObject
@end