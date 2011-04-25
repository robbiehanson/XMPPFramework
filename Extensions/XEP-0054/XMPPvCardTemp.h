//
//  XMPPvCardTemp.h
//  XEP-0054 vCard-temp
//
//  Created by Eric Chamberlain on 3/9/11.
//  Copyright 2011 RF.com. All rights reserved.
//  Copyright 2010 Martin Morrison. All rights reserved.
//


#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

#import "XMPPIQ.h"
#import "XMPPJID.h"
#import "XMPPUser.h"
#import "XMPPvCardTempAdr.h"
#import "XMPPvCardTempBase.h"
#import "XMPPvCardTempEmail.h"
#import "XMPPvCardTempLabel.h"
#import "XMPPvCardTempTel.h"


typedef enum _XMPPvCardTempClass {
	XMPPvCardTempClassNone,
	XMPPvCardTempClassPublic,
	XMPPvCardTempClassPrivate,
	XMPPvCardTempClassConfidential,
} XMPPvCardTempClass;


extern NSString *const kXMPPNSvCardTemp;
extern NSString *const kXMPPvCardTempElement;


/*
 * Note: according to the DTD, every fields bar N and FN can appear multiple times.
 * The provided accessors only support this for the field types where multiple
 * entries make sense - for the others, if required, the NSXMLElement accessors
 * must be used.
 */
@interface XMPPvCardTemp : XMPPvCardTempBase


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
@property (nonatomic, assign) XMPPvCardTemp *agent;
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

@property (nonatomic, assign) XMPPvCardTempClass privacyClass;
@property (nonatomic, assign) NSData *key;
@property (nonatomic, assign) NSString *keyType;


+ (XMPPvCardTemp *)vCardTempFromElement:(NSXMLElement *)element;
+ (XMPPvCardTemp *)vCardTempSubElementFromIQ:(XMPPIQ *)iq;
+ (XMPPvCardTemp *)vCardTempCopyFromIQ:(XMPPIQ *)iq;
+ (XMPPIQ *)iqvCardRequestForJID:(XMPPJID *)jid;


- (void)addAddress:(XMPPvCardTempAdr *)adr;
- (void)removeAddress:(XMPPvCardTempAdr *)adr;
- (void)clearAddresses;


- (void)addLabel:(XMPPvCardTempLabel *)label;
- (void)removeLabel:(XMPPvCardTempLabel *)label;
- (void)clearLabels;


- (void)addTelecomsAddress:(XMPPvCardTempTel *)tel;
- (void)removeTelecomsAddress:(XMPPvCardTempTel *)tel;
- (void)clearTelecomsAddresses;


- (void)addEmailAddress:(XMPPvCardTempEmail *)email;
- (void)removeEmailAddress:(XMPPvCardTempEmail *)email;
- (void)clearEmailAddresses;


@end
