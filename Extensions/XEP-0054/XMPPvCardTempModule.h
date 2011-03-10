//
//  XMPPvCardTempModule.h
//  XEP-0054 vCard-temp
//
//  Created by Eric Chamberlain on 3/9/11.
//  Copyright 2011 RF.com. All rights reserved.
//  Copyright 2010 Martin Morrison. All rights reserved.
//

/*
 * Implementation of XEP-0054 vCard-temp
 *
 * Consists of the following classes/protocols:
 * - XMPPvCardTempModule - the XMPPModule. Instantiate one of these to fetch vCards.
 * - XMPPvCardTempStorage - protocol for persistence of vCards.
 * - XMPPvCardTempModuleDelegate - protocol for objects wishing to be notified of new vCards.
 *
 * The following are all NSXMLElement subclasses providing accessor methods for the supported fields:
 * - XMPPvCard - represents a <vCard/> element.
 * - XMPPvCardEmail - an <EMAIL/> child of a <vCard/> element.
 * - XMPPvCardTel - a <TEL/> child of a <vCard/> element.
 * - XMPPvCardAdr - an <ADR/> child of a <vCard/> element.
 * - XMPPvCardLabel - a <LABEL/> child of a <vCard/> element.
 */


#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE
#import "DDXML.h"
#endif

#import "NSXMLElementAdditions.h"
#import "XMPPJID.h"
#import "XMPPModule.h"
#import "XMPPStream.h"
#import "XMPPvCard.h"


@protocol XMPPvCardTempModuleDelegate;
@protocol XMPPvCardTempStorage;


@interface XMPPvCardTempModule : XMPPModule <XMPPStreamDelegate> {
	BOOL _autoFetch;
	id <XMPPvCardTempStorage> _storage;
}


@property (nonatomic, assign) BOOL autoFetch;
@property (nonatomic, retain, readonly) id <XMPPvCardTempStorage> storage;


- (id)initWithStream:(XMPPStream *)stream 
             storage:(id <XMPPvCardTempStorage>)storage
           autoFetch:(BOOL)autoFetch;


/*
 * Is a vCard stored locally for this JID?
 */
- (BOOL)havevCardForJID:(XMPPJID *)jid;


/*
 * Return the vCard for the given JID, if stored locally.
 * If the vCard is not local, fetch the vCard from the server asynchronously and return nil.
 */
- (XMPPvCard *)vCardForJID:(XMPPJID *)jid;


/*
 * Remove the stored vCard for the given JID.
 */
- (void)removevCardForJID:(XMPPJID *)jid;


@end


#pragma mark -
#pragma mark XMPPvCardTempModuleDelegate


@protocol XMPPvCardTempModuleDelegate


@optional


- (void)xmppvCardTempModule:(XMPPvCardTempModule *)vCardTempModule 
            didReceivevCard:(XMPPvCard *)vCard 
                     forJID:(XMPPJID *)jid;


@end


#pragma mark -
#pragma mark XMPPvCardTempStorage


@protocol XMPPvCardTempStorage <NSObject>


/*
 * Is a vCard stored locally for this JID?
 */
- (BOOL)havevCardForJID:(XMPPJID *)jid;


/*
 * The vCard for the given JID.
 */
- (XMPPvCard *)vCardForJID:(XMPPJID *)jid;


/*
 * Save the given vCard for the given JID.
 */
- (void)savevCard:(XMPPvCard *)vCard forJID:(XMPPJID *)jid;


/*
 * Remove any stored vCard for the given JID.
 */
- (void)removevCardForJID:(XMPPJID *)jid;


@end
