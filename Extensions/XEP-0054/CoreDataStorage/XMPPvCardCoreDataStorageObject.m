//
//  XMPPvCardCoreDataStorageObject.m
//  XEP-0054 vCard-temp
//
//  Originally created by Eric Chamberlain on 3/18/11.
//

#import "XMPPvCardCoreDataStorageObject.h"
#import "XMPPvCardTempCoreDataStorageObject.h"
#import "XMPPvCardAvatarCoreDataStorageObject.h"

#import "XMPPJID.h"
#import "XMPPStream.h"
#import "NSNumber+XMPP.h"
#import "NSData+XMPP.h"


@implementation XMPPvCardCoreDataStorageObject

+ (XMPPvCardCoreDataStorageObject *)fetchvCardForJID:(XMPPJID *)jid
                              inManagedObjectContext:(NSManagedObjectContext *)moc
{
	NSString *entityName = NSStringFromClass([XMPPvCardCoreDataStorageObject class]);
	
	NSEntityDescription *entity = [NSEntityDescription entityForName:entityName
	                                          inManagedObjectContext:moc];
	
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"jidStr == %@", [jid bare]];
	
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	[fetchRequest setEntity:entity];
	[fetchRequest setPredicate:predicate];
	[fetchRequest setIncludesPendingChanges:YES];
	[fetchRequest setFetchLimit:1];
	
	NSArray *results = [moc executeFetchRequest:fetchRequest error:nil];
	
	[fetchRequest release];
	
	return (XMPPvCardCoreDataStorageObject *)[results lastObject];
}


+ (XMPPvCardCoreDataStorageObject *)insertEmptyvCardForJID:(XMPPJID *)jid
                                    inManagedObjectContext:(NSManagedObjectContext *)moc
{
	NSString *entityName = NSStringFromClass([XMPPvCardCoreDataStorageObject class]);
	
	XMPPvCardCoreDataStorageObject *vCard = [NSEntityDescription insertNewObjectForEntityForName:entityName
	                                                                      inManagedObjectContext:moc];
	
	vCard.jidStr = [jid bare];
	return vCard;
}

+ (XMPPvCardCoreDataStorageObject *)fetchOrInsertvCardForJID:(XMPPJID *)jid
                                      inManagedObjectContext:(NSManagedObjectContext *)moc
{
	XMPPvCardCoreDataStorageObject *vCard = [self fetchvCardForJID:jid inManagedObjectContext:moc];
	if (vCard == nil)
	{
		vCard = [self insertEmptyvCardForJID:jid inManagedObjectContext:moc];
	}
	
	return vCard;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark NSManagedObject methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)awakeFromInsert
{
	[super awakeFromInsert];
	[self setPrimitiveValue:[NSDate date] forKey:@"lastUpdated"];
}


- (void)willSave
{
	/*
	if (![self isDeleted] && [self isUpdated]) {
		[self setPrimitiveValue:[NSDate date] forKey:@"lastUpdated"];
	}
	*/
	
	[super willSave];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Getter/setter methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@dynamic jidStr;
@dynamic photoHash;
@dynamic lastUpdated;
@dynamic waitingForFetch;
@dynamic vCardTempRel;
@dynamic vCardAvatarRel;


- (NSData *)photoData {
	return self.vCardAvatarRel.photoData;
}


- (void)setPhotoData:(NSData *)photoData
{
	if (photoData == nil)
	{
		if (self.vCardAvatarRel != nil)
		{
			[[self managedObjectContext] deleteObject:self.vCardAvatarRel];
			[self setPrimitiveValue:nil forKey:@"photoHash"];
		}
		
		return;
	}
	
	if (self.vCardAvatarRel == nil)
	{
		NSString *entityName = NSStringFromClass([XMPPvCardAvatarCoreDataStorageObject class]);
		
		self.vCardAvatarRel = [NSEntityDescription insertNewObjectForEntityForName:entityName
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


- (void)setVCardTemp:(XMPPvCardTemp *)vCardTemp
{
	if (vCardTemp == nil && self.vCardTempRel != nil)
	{
		[[self managedObjectContext] deleteObject:self.vCardTempRel];
		
		return;
	}
	
	if (self.vCardTempRel == nil)
	{
		NSString *entityName = NSStringFromClass([XMPPvCardTempCoreDataStorageObject class]);
		
		self.vCardTempRel = [NSEntityDescription insertNewObjectForEntityForName:entityName
		                                                  inManagedObjectContext:[self managedObjectContext]];
	}
	
	[self willChangeValueForKey:@"vCardTemp"];
	self.vCardTempRel.vCardTemp = vCardTemp;
	[self didChangeValueForKey:@"vCardTemp"];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark KVO methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (NSSet *)keyPathsForValuesAffectingPhotoHash
{
	return [NSSet setWithObjects:@"vCardAvatarRel", @"photoData", nil];
}

+ (NSSet *)keyPathsForValuesAffectingVCardTemp
{
	return [NSSet setWithObject:@"vCardTempRel"];
}

@end
