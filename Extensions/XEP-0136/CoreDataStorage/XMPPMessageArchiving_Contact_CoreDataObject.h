#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "XMPP.h"


@interface XMPPMessageArchiving_Contact_CoreDataObject : NSManagedObject

@property (nonatomic, strong) XMPPJID * bareJid;      // Transient (proper type, not on disk)
@property (nonatomic, strong) NSString * bareJidStr;  // Shadow (binary data, written to disk)

@property (nonatomic, strong) NSDate * mostRecentMessageTimestamp;
@property (nonatomic, strong) NSString * mostRecentMessageBody;
@property (nonatomic, strong) NSNumber * mostRecentMessageOutgoing;

@property (nonatomic, strong) NSString * streamBareJidStr;

/**
 * This method is called immediately before the object is inserted into the managedObjectContext.
 * At this point, all normal properties have been set.
 * 
 * If you extend XMPPMessageArchiving_Contact_CoreDataObject,
 * you can use this method as a hook to set your custom properties.
**/
- (void)willInsertObject;

/**
 * This method is called after any properties on the object have been updated,
 * due to a message being added to the conversation.
 * At this point, any changed properties have been updated.
 * 
 * If you extend XMPPMessageArchiving_Contact_CoreDataObject,
 * you can use this method as a hook to update your custom properties.
**/
- (void)didUpdateObject;

@end
