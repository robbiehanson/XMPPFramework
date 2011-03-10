//
//  XMPPvCard.h
//  XEP-0054 vCard-temp
//
//  Created by Eric Chamberlain on 3/9/11.
//  Copyright 2011 RF.com. All rights reserved.
//  Copyright 2010 Martin Morrison. All rights reserved.
//


#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

#import "XMPPJID.h"
#import "XMPPvCardAdr.h"
#import "XMPPvCardBase.h"
#import "XMPPvCardEmail.h"
#import "XMPPvCardLabel.h"
#import "XMPPvCardTel.h"


typedef enum _XMPPvCardClass {
	XMPPvCardClassNone,
	XMPPvCardClassPublic,
	XMPPvCardClassPrivate,
	XMPPvCardClassConfidential,
} XMPPvCardClass;


/*
 * Note: according to the DTD, every fields bar N and FN can appear multiple times.
 * The provided accessors only support this for the field types where multiple
 * entries make sense - for the others, if required, the NSXMLElement accessors
 * must be used.
 */
@interface XMPPvCard : XMPPvCardBase


@property (nonatomic, assign) NSDate *bday;
@property (nonatomic, assign) NSData *photo;
@property (nonatomic, assign) NSString *nickname;
@property (nonatomic, assign) NSString *formattedName;
@property (nonatomic, assign) NSString *familyName;
@property (nonatomic, assign) NSString *givenName;
@property (nonatomic, assign) NSString *middleName;
@property (nonatomic, assign) NSString *prefix;
@property (nonatomic, assign) NSString *suffix;

@property (nonatomic, assign) NSArray *addresses;
@property (nonatomic, assign) NSArray *labels;
@property (nonatomic, assign) NSArray *telecomsAddresses;
@property (nonatomic, assign) NSArray *emailAddresses;

@property (nonatomic, assign) XMPPJID *jid;
@property (nonatomic, assign) NSString *mailer;

@property (nonatomic, assign) NSTimeZone *timeZone;
@property (nonatomic, assign) CLLocation *location;

@property (nonatomic, assign) NSString *title;
@property (nonatomic, assign) NSString *role;
@property (nonatomic, assign) NSData *logo;
@property (nonatomic, assign) XMPPvCard *agent;
@property (nonatomic, assign) NSString *orgName;

/*
 * ORGUNITs can only be set if there is already an ORGNAME. Otherwise, changes are ignored.
 */
@property (nonatomic, assign) NSArray *orgUnits;

@property (nonatomic, assign) NSArray *categories;
@property (nonatomic, assign) NSString *note;
@property (nonatomic, assign) NSString *prodid;
@property (nonatomic, assign) NSDate *revision;
@property (nonatomic, assign) NSString *sortString;
@property (nonatomic, assign) NSString *phoneticSound;
@property (nonatomic, assign) NSData *sound;
@property (nonatomic, assign) NSString *uid;
@property (nonatomic, assign) NSString *url;
@property (nonatomic, assign) NSString *version;
@property (nonatomic, assign) NSString *description;

@property (nonatomic, assign) XMPPvCardClass privacyClass;
@property (nonatomic, assign) NSData *key;
@property (nonatomic, assign) NSString *keyType;


+ (XMPPvCard *)vCardFromElement:(NSXMLElement *)element;


- (void)addAddress:(XMPPvCardAdr *)adr;
- (void)removeAddress:(XMPPvCardAdr *)adr;
- (void)clearAddresses;


- (void)addLabel:(XMPPvCardLabel *)label;
- (void)removeLabel:(XMPPvCardLabel *)label;
- (void)clearLabels;


- (void)addTelecomsAddress:(XMPPvCardTel *)tel;
- (void)removeTelecomsAddress:(XMPPvCardTel *)tel;
- (void)clearTelecomsAddresses;


- (void)addEmailAddress:(XMPPvCardEmail *)email;
- (void)removeEmailAddress:(XMPPvCardEmail *)email;
- (void)clearEmailAddresses;


@end
