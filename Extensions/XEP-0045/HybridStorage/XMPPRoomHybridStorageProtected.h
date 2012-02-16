/**
 * The XMPPRoomHybridStorage class is designed to be easily extensible.
 * The class has several protected methods that act as hooks,
 * allowing you to override various methods to customize the functionality how you see fit.
 * 
 * This header file lists the protected methods,
 * and you may need to import it in your subclass if you ever need to invoke these methods directly.
 * 
 * E.g. [super insertOccupant...]
**/

@interface XMPPRoomHybridStorage (Protected)

/**
 * Returns whether or not the given message already exists in storage.
 * If YES, then the message is ignored. Otherwise it is passed to the insert routines.
**/
- (BOOL)existsMessage:(XMPPMessage *)message forRoom:(XMPPRoom *)room stream:(XMPPStream *)xmppStream;

/**
 * Override me if you're extending the XMPPRoomMessageHybridCoreDataStorageObject class
 * to add additional properties, which you can set here.
 * 
 * At this point the standard properties have already been set.
 * So you can, for example, access the XMPPMessage via message.message.
**/
- (void)didInsertMessage:(XMPPRoomMessageHybridCoreDataStorageObject *)message;

/**
 * Optional override hook for complete customization.
 * Override me if you need to do specific custom work when inserting a message in a room.
**/
- (void)insertMessage:(XMPPMessage *)message
             outgoing:(BOOL)isOutgoing
              forRoom:(XMPPRoom *)room
               stream:(XMPPStream *)xmppStream;

/**
 * Override me if you're extending the XMPPRoomOccupantHybridMemoryStorageObject class
 * to add additional properties, which you can set here.
 * 
 * At this point the standard properties have already been set.
 * So you can, for example, access the XMPPPresence via occupant.presece.
**/
- (void)didInsertOccupant:(XMPPRoomOccupantHybridMemoryStorageObject *)occupant;

/**
 * Override me if you're extending the XMPPRoomOccupantHybridMemoryStorageObject class,
 * and you have additional properties that may need to be updated.
 * 
 * At this point the standard properties have already been updated.
**/
- (void)didUpdateOccupant:(XMPPRoomOccupantHybridMemoryStorageObject *)occupant;

/**
 * Override me if you have any custom work to do before an occupant leaves (is removed from storage).
**/
- (void)willRemoveOccupant:(XMPPRoomOccupantHybridMemoryStorageObject *)occupant;

/**
 * Override me if you have any custom work to do after an occupant leaves (is removed from storage).
**/
- (void)didRemoveOccupant:(XMPPRoomOccupantHybridMemoryStorageObject *)occupant;

/**
 * Optional override hook for complete customization.
 * Override me if you need to do custom work when inserting an occupant in a room.
**/ 
- (XMPPRoomOccupantHybridMemoryStorageObject *)insertOccupantWithPresence:(XMPPPresence *)presence
                                                                     room:(XMPPRoom *)room
                                                                   stream:(XMPPStream *)xmppStream;

/**
 * Optional override hook for complete customization.
 * Override me if you need to do custom work when updating an occupant in a room.
**/
- (void)updateOccupant:(XMPPRoomOccupantHybridMemoryStorageObject *)occupant
          withPresence:(XMPPPresence *)presence
                  room:(XMPPRoom *)room
                stream:(XMPPStream *)stream;

/**
 * Optional override hook for complete customization.
 * Override me if you need to do custom work when removing an occupant from a room.
**/
- (void)removeOccupant:(XMPPRoomOccupantHybridMemoryStorageObject *)occupant
          withPresence:(XMPPPresence *)presence
                  room:(XMPPRoom *)room
                stream:(XMPPStream *)stream;

@end
