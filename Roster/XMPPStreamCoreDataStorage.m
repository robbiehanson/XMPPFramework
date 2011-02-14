//
//  XMPPStreamCoreDataStorage.m
//
//  Created by Eric Chamberlain on 9/29/10.
//  Copyright 2010 RF.com. All rights reserved.
//

#import "XMPPStreamCoreDataStorage.h"

#import "DDLog.h"
#import "XMPPJID.h"
#import "XMPPStream.h"
#import "XMPPUserCoreDataStorage.h"

@implementation XMPPStreamCoreDataStorage

@dynamic myJIDStr;
@dynamic users;

#pragma mark -

+ (id)insertInManagedObjectContext:(NSManagedObjectContext *)moc withStream:(XMPPStream *)stream {
    XMPPJID *jid = [stream myJID];
	
	if (jid == nil)
	{
		DDLogError(@"%s invalid stream (missing or invalid jid)", __PRETTY_FUNCTION__);
		return nil;
	}
	
    XMPPStreamCoreDataStorage *newStream = [NSEntityDescription insertNewObjectForEntityForName:@"XMPPStreamCoreDataStorage"
                                                                         inManagedObjectContext:moc];
    newStream.myJIDStr = [jid full];
    
	return newStream;
}

+ (id)getOrInsertInManagedObjectContext:(NSManagedObjectContext *)moc
                         withXMPPStream:(XMPPStream *)xmppStream {
    NSString *myJIDStr = [[xmppStream myJID] full];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPStreamCoreDataStorage"
	                                          inManagedObjectContext:moc];
	
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"myJIDStr == %@", myJIDStr];
	
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	[fetchRequest setEntity:entity];
	[fetchRequest setPredicate:predicate];
	[fetchRequest setIncludesPendingChanges:YES];
	[fetchRequest setFetchLimit:1];
	
	NSArray *results = [moc executeFetchRequest:fetchRequest error:nil];
	
	[fetchRequest release];
    
    if ([results count] > 0) {
        return [results objectAtIndex:0];
    }
    
    return [self insertInManagedObjectContext:moc withStream:xmppStream];
}

@end
