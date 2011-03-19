//
//  XMPPvCardCoreDataStorage.m
//  XEP-0054 vCard-temp
//
//  Created by Eric Chamberlain on 3/18/11.
//  Copyright (c) 2011 RF.com. All rights reserved.
//

#import "XMPPvCardCoreDataStorage.h"

#import "NSDataAdditions.h"
#import "XMPPJID.h"
#import "XMPPvCardAvatarCoreDataStorage.h"
#import "XMPPvCardTempCoreDataStorage.h"


@interface XMPPvCardCoreDataStorage()


+ (XMPPvCardCoreDataStorage *)fetchvCardForJID:(XMPPJID *)jid 
                        inManagedObjectContext:(NSManagedObjectContext *)moc;

+ (XMPPvCardCoreDataStorage *)insertEmptyvCardForJID:(XMPPJID *)jid 
                              inManagedObjectContext:(NSManagedObjectContext *)moc;


@end

@implementation XMPPvCardCoreDataStorage


+ (XMPPvCardCoreDataStorage *)fetchOrInsertvCardForJID:(XMPPJID *)jid
                                inManagedObjectContext:(NSManagedObjectContext *)moc {
  XMPPvCardCoreDataStorage *vCard = [self fetchvCardForJID:jid inManagedObjectContext:moc];
  
  if (vCard == nil) {
    vCard = [self insertEmptyvCardForJID:jid inManagedObjectContext:moc];
  }
  return vCard;
}

+ (XMPPvCardCoreDataStorage *)fetchvCardForJID:(XMPPJID *)jid 
                        inManagedObjectContext:(NSManagedObjectContext *)moc {
  NSEntityDescription *entity = [NSEntityDescription entityForName:NSStringFromClass([XMPPvCardCoreDataStorage class])
	                                          inManagedObjectContext:moc];
	
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"jidStr == %@", [jid bare]];
	
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	[fetchRequest setEntity:entity];
	[fetchRequest setPredicate:predicate];
	[fetchRequest setIncludesPendingChanges:YES];
	[fetchRequest setFetchLimit:1];
	
	NSArray *results = [moc executeFetchRequest:fetchRequest error:nil];
	
	[fetchRequest release];
  
  XMPPvCardCoreDataStorage *vCard = nil;
  
  if ([results count] > 0) {
    vCard = (XMPPvCardCoreDataStorage *)[results objectAtIndex:0];
  }
  return vCard;
}


+ (XMPPvCardCoreDataStorage *)insertEmptyvCardForJID:(XMPPJID *)jid 
                              inManagedObjectContext:(NSManagedObjectContext *)moc {
  XMPPvCardCoreDataStorage *newvCard = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([XMPPvCardCoreDataStorage class])
                                                                       inManagedObjectContext:moc];
  newvCard.jidStr = [jid bare];
  return newvCard;
}


#pragma mark - NSManagedObject methods

- (void)awakeFromInsert {
  [super awakeFromInsert];
  
  [self setPrimitiveValue:[NSDate date] forKey:@"lastUpdated"];
}


- (void)willSave {
  /*
  if (![self isDeleted] && [self isUpdated]) {
    [self setPrimitiveValue:[NSDate date] forKey:@"lastUpdated"];
  }
  */
  [super willSave];
}


#pragma mark - Getter/setter methods


@dynamic jidStr;
@dynamic photoHash;
@dynamic lastUpdated;
@dynamic waitingForFetch;
@dynamic vCardTempRel;
@dynamic vCardAvatarRel;


- (NSData *)photoData {
  return self.vCardAvatarRel.photoData;
}


- (void)setPhotoData:(NSData *)photoData {
  
  if (photoData == nil && self.vCardAvatarRel != nil) {
    [[self managedObjectContext] deleteObject:self.vCardAvatarRel];
    [self setPrimitiveValue:nil forKey:@"photoHash"];
    return;
  }
  
  if (self.vCardAvatarRel == nil) {
    self.vCardAvatarRel = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([XMPPvCardAvatarCoreDataStorage class]) 
                                                        inManagedObjectContext:[self managedObjectContext]];
  }
  [self willChangeValueForKey:@"photoData"];
  self.vCardAvatarRel.photoData = photoData;
  [self didChangeValueForKey:@"photoData"];
  
  [self setPrimitiveValue:[[photoData sha1Digest] hexStringValue] forKey:@"photoHash"];
}


- (XMPPvCardTemp *)vCardTemp {
  return self.vCardTempRel.vCardTemp;
}


- (void)setVCardTemp:(XMPPvCardTemp *)vCardTemp {
  if (vCardTemp == nil && self.vCardTempRel != nil) {
    [[self managedObjectContext] deleteObject:self.vCardTempRel];
    return;
  }
  
  if (self.vCardTempRel == nil) {
    // insert vCardTemp
    self.vCardTempRel = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([XMPPvCardTempCoreDataStorage class])
                                                      inManagedObjectContext:[self managedObjectContext]];
  }
  [self willChangeValueForKey:@"vCardTemp"];
  self.vCardTempRel.vCardTemp = vCardTemp;
  [self didChangeValueForKey:@"vCardTemp"];
}


#pragma mark - KVO methods


+ (NSSet *)keyPathsForValuesAffectingPhotoHash {
  return [NSSet setWithObjects:@"vCardAvatarRel",@"photoData",nil];
}


+ (NSSet *)keyPathsForValuesAffectingVCardTemp {
  return [NSSet setWithObject:@"vCardTempRel"];
}


@end
