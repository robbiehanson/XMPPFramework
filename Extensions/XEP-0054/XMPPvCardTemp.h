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

NS_ASSUME_NONNULL_BEGIN
extern NSString *const kXMPPNSvCardTemp;
extern NSString *const kXMPPvCardTempElement;


/*
 * Note: according to the DTD, every fields bar N and FN can appear multiple times.
 * The provided accessors only support this for the field types where multiple
 * entries make sense - for the others, if required, the NSXMLElement accessors
 * must be used.
 */
@interface XMPPvCardTemp : XMPPvCardTempBase


@property (nonatomic, strong, nullable) NSDate *bday;
@property (nonatomic, strong, nullable) NSData *photo;
@property (nonatomic, strong, nullable) NSString *nickname;
@property (nonatomic, strong, nullable) NSString *formattedName;
@property (nonatomic, strong, nullable) NSString *familyName;
@property (nonatomic, strong, nullable) NSString *givenName;
@property (nonatomic, strong, nullable) NSString *middleName;
/** This property used to collide with the NSXMLNode prefix */
@property (nonatomic, strong, nullable) NSString *vPrefix;
@property (nonatomic, strong, nullable) NSString *suffix;

@property (nonatomic, strong, nullable) NSArray<XMPPvCardTempAdr*> *addresses;
@property (nonatomic, strong, nullable) NSArray<XMPPvCardTempLabel*> *labels;
@property (nonatomic, strong, nullable) NSArray<XMPPvCardTempTel*> *telecomsAddresses;
@property (nonatomic, strong) NSArray<XMPPvCardTempEmail*> *emailAddresses;

@property (nonatomic, strong, nullable) XMPPJID *jid;
@property (nonatomic, strong, nullable) NSString *mailer;

@property (nonatomic, strong, nullable) NSTimeZone *timeZone;
@property (nonatomic, strong, nullable) CLLocation *location;

@property (nonatomic, strong, nullable) NSString *title;
@property (nonatomic, strong, nullable) NSString *role;
@property (nonatomic, strong, nullable) NSData *logo;
@property (nonatomic, strong, nullable) XMPPvCardTemp *agent;
@property (nonatomic, strong, nullable) NSString *orgName;

/*
 * ORGUNITs can only be set if there is already an ORGNAME. Otherwise, changes are ignored.
 */
@property (nonatomic, strong, nullable) NSArray<NSString*> *orgUnits;

@property (nonatomic, strong, nullable) NSArray<NSString*> *categories;
@property (nonatomic, strong, nullable) NSString *note;
@property (nonatomic, strong, nullable) NSString *prodid;
@property (nonatomic, strong, nullable) NSDate *revision;
@property (nonatomic, strong, nullable) NSString *sortString;
@property (nonatomic, strong, nullable) NSString *phoneticSound;
@property (nonatomic, strong, nullable) NSData *sound;
@property (nonatomic, strong, nullable) NSString *uid;
@property (nonatomic, strong, nullable) NSString *url;
@property (nonatomic, strong, nullable) NSString *version;
@property (nonatomic, strong, nullable) NSString *desc;

@property (nonatomic, assign) XMPPvCardTempClass privacyClass;
@property (nonatomic, strong, nullable) NSData *key;
@property (nonatomic, strong, nullable) NSString *keyType;

+ (XMPPvCardTemp *)vCardTempFromElement:(NSXMLElement *)element;
+ (XMPPvCardTemp *)vCardTemp;
+ (nullable XMPPvCardTemp *)vCardTempSubElementFromIQ:(XMPPIQ *)iq;
+ (nullable XMPPvCardTemp *)vCardTempCopyFromIQ:(XMPPIQ *)iq;
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
NS_ASSUME_NONNULL_END
