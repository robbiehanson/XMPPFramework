#import "XMPPMessageArchivingCoreDataStorage.h"
#import "XMPPCoreDataStorageProtected.h"


@implementation XMPPMessageArchivingCoreDataStorage

static XMPPMessageArchivingCoreDataStorage *sharedInstance;

+ (XMPPMessageArchivingCoreDataStorage *)sharedInstance
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		
		sharedInstance = [[XMPPMessageArchivingCoreDataStorage alloc] initWithDatabaseFilename:nil];
	});
	
	return sharedInstance;
}

- (BOOL)configureWithParent:(XMPPMessageArchiving *)aParent queue:(dispatch_queue_t)queue
{
	return [super configureWithParent:aParent queue:queue];
}

- (void)archiveMessage:(XMPPMessage *)message outgoing:(BOOL)isOutgoing xmppStream:(XMPPStream *)xmppStream
{
	[self scheduleBlock:^{
		
		NSString *thread = [[message elementForName:@"thread"] stringValue];
		
		XMPPMessageArchivingCoreDataStorageObject *archivedMessage = 
		    [NSEntityDescription insertNewObjectForEntityForName:@"XMPPMessageArchivingCoreDataStorageObject"
		                                  inManagedObjectContext:[self managedObjectContext]];
		
		archivedMessage.message = message;
		
		if (isOutgoing)
			archivedMessage.bareJid = [[message to] bareJID];
		else
			archivedMessage.bareJid = [[message from] bareJID];
		
		archivedMessage.thread = thread;
		archivedMessage.isOutgoing = isOutgoing;
		
		archivedMessage.streamBareJidStr = [[self myJIDForXMPPStream:xmppStream] bare];
	}];
}

@end
