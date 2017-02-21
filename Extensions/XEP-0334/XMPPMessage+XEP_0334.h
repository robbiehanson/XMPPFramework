//
//  XMPPMessage+XEP_0334.h
//  Pods
//
//  Created by Chris Ballinger on 4/16/16.
//
//

#import "XMPPMessage.h"

typedef NS_ENUM(NSInteger, XMPPMessageStorage) {
    /** 
     Unknown storage hint. Attempting to add this is a no-op. 
     */
    XMPPMessageStorageUnknown,
    /**
      The <no-permanent-store/> hint informs entities that they shouldn't store the message in any permanent or semi-permanent public or private archive (such as described in Message Archiving (XEP-0136) [5] and Message Archive Management (XEP-0313) [6]) or in logs (such as chatroom logs).
     */
    XMPPMessageStorageNoPermanentStore,
    /**
      A message containing a <no-store/> hint should not be stored by a server either permanently (as above) or temporarily, e.g. for later delivery to an offline client, or to users not currently present in a chatroom.
     */
    XMPPMessageStorageNoStore,
    /**
     Messages with the <no-copy/> hint should not be copied to addresses other than the one to which it is addressed, for example through Message Carbons (XEP-0280) [7].
     
     This hint MUST only be included on messages addressed to full JIDs and explicitly does not override the behaviour defined in XMPP IM [8] for handling messages to bare JIDs, which may involve copying to multiple resources, or multiple occupants in a Multi-User Chat (XEP-0045) [9] room.
     */
    XMPPMessageStorageNoCopy,
    /**
      A message containing the <store/> hint that is not of type 'error' SHOULD be stored by the entity.
     */
    XMPPMessageStorageStore
};

/**
 XEP-0334: Message Processing Hints
 http://xmpp.org/extensions/xep-0334.html
 
 This specification aims to solve the following common problems, and allow a sender to hint to the recipient:
 
  - Whether to store a message (e.g. for archival or as an 'offline message').
  - Whether to copy a message to other resources.
  - Whether to store a message that would not have been stored under normal conditions
 */
@interface XMPPMessage (XEP_0334)

/** add a storage hint to message element */
-(void) addStorageHint:(XMPPMessageStorage)storageHint;

/** Contains array of boxed XMPPMessageStorage values present in the message element. Empty array if none found. */
- (nonnull NSArray<NSValue*>*)storageHints;

@end
