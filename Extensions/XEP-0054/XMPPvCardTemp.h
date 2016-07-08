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


@property (nonatomic, strong) NSDate *bday;
@property (nonatomic, strong) NSData *photo;
@property (nonatomic, strong) NSString *nickname;
@property (nonatomic, strong) NSString *formattedName;
@property (nonatomic, strong) NSString *familyName;
@property (nonatomic, strong) NSString *givenName;
@property (nonatomic, strong) NSString *middleName;
/** This property used to collide with the NSXMLNode prefix */
@property (nonatomic, strong) NSString *vPrefix;
@property (nonatomic, strong) NSString *suffix;

@property (nonatomic, strong) NSArray *addresses;
@property (nonatomic, strong) NSArray *labels;
@property (nonatomic, strong) NSArray *telecomsAddresses;
@property (nonatomic, strong) NSArray *emailAddresses;

@property (nonatomic, strong) XMPPJID *jid;
@property (nonatomic, strong) NSString *mailer;

@property (nonatomic, strong) NSTimeZone *timeZone;
@property (nonatomic, strong) CLLocation *location;

@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *role;
@property (nonatomic, strong) NSData *logo;
@property (nonatomic, strong) XMPPvCardTemp *agent;
@property (nonatomic, strong) NSString *orgName;

/*
 * ORGUNITs can only be set if there is already an ORGNAME. Otherwise, changes are ignored.
 */
@property (nonatomic, strong) NSArray *orgUnits;

@property (nonatomic, strong) NSArray *categories;
@property (nonatomic, strong) NSString *note;
@property (nonatomic, strong) NSString *prodid;
@property (nonatomic, strong) NSDate *revision;
@property (nonatomic, strong) NSString *sortString;
@property (nonatomic, strong) NSString *phoneticSound;
@property (nonatomic, strong) NSData *sound;
@property (nonatomic, strong) NSString *uid;
@property (nonatomic, strong) NSString *url;
@property (nonatomic, strong) NSString *version;
@property (nonatomic, strong) NSString *desc;

@property (nonatomic, assign) XMPPvCardTempClass privacyClass;
@property (nonatomic, strong) NSData *key;
@property (nonatomic, strong) NSString *keyType;

+ (XMPPvCardTemp *)vCardTempFromElement:(NSXMLElement *)element;
+ (XMPPvCardTemp *)vCardTemp;
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
