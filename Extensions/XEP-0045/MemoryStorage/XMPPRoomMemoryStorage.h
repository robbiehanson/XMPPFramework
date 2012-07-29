#import <Foundation/Foundation.h>
#import "XMPPRoom.h"
#import "XMPPRoomOccupant.h"
#import "XMPPRoomMessageMemoryStorageObject.h"
#import "XMPPRoomOccupantMemoryStorageObject.h"



@interface XMPPRoomMemoryStorage : NSObject <XMPPRoomStorage>

- (id)init;

@property (readonly) XMPPRoom *parent;

/**
 * You can optionally extend the XMPPRoomMessageMemoryStorageObject and XMPPRoomOccupantMemoryStorageObject classes.
 * Then just set the classes here, and your subclasses will automatically get used.
 * 
 * You must set your desired class(es), if different from default, before you begin using the storage class.
**/
@property (assign, readwrite) Class messageClass;
@property (assign, readwrite) Class occupantClass;

/**
 * Returns the occupant with the given full JID.
**/
- (XMPPRoomOccupantMemoryStorageObject *)occupantForJID:(XMPPJID *)jid;

/**
 * Returns the messages in sorted order.
 * The messages are sorted via the [messageClass compare:] method, which may optionally be overriden in subclasses.
**/
- (NSArray *)messages;

/**
 * Returns the occupants in sorted order.
 * The occupants are sorted via the [occupantsClass compare:] method, which may optionally be overriden in subclasses.
**/
- (NSArray *)occupants;

/**
 * This method is designed for subclasses of XMPPRoomMessageMemoryStorageObject
 * which may dynamically change the operation of the overriden compare: method.
 * 
 * If changed, this method should be invoked to force a resort.
**/
- (NSArray *)resortMessages;

/**
 * This method is designed for subclasses of XMPPRoomOccupantMemoryStorageObject
 * which may dynamically change the operation of the overriden compare: method.
 * 
 * If changed, this method should be invoked to force a resort.
**/
- (NSArray *)resortOccupants;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol XMPPRoomMemoryStorageDelegate <NSObject>
@optional

// 
// XMPPRoomMemoryStorage automatically uses the delegate(s) of its parent XMPPRoom.
// 

/**
 * Similar to XMPPRoomDelegate's xmppRoom:occupantDidJoin:withPresence: method.
 * 
 * This method provides the delegate with the occupant storage instance,
 * as well as the current snapshot of the occupants array,
 * and the index at which the new occupant was inserted.
 * 
 * The given occupant will be included in the given array at the given index.
**/
- (void)xmppRoomMemoryStorage:(XMPPRoomMemoryStorage *)sender
              occupantDidJoin:(XMPPRoomOccupantMemoryStorageObject *)occupant
                      atIndex:(NSUInteger)index
                      inArray:(NSArray *)allOccupants;

/**
 * Similar to XMPPRoomDelegate's xmppRoom:occupantDidLeave:withPresence: method.
 * 
 * This method provides the delegate with the occupant storage instance,
 * as well as the current snapshot of the occupants array,
 * and the index at which the occupant used to reside.
 * 
 * The given occupant will not be included in the given array.
 * It's previous location is given by the index.
**/
- (void)xmppRoomMemoryStorage:(XMPPRoomMemoryStorage *)sender
             occupantDidLeave:(XMPPRoomOccupantMemoryStorageObject *)occupant
                      atIndex:(NSUInteger)index
                    fromArray:(NSArray *)allOccupants;

/**
 * Similar to XMPPRoomDelegate's xmppRoom:occupantDidUpdate:withPresence: method.
 * 
 * This method provides the delegate with the occupant storage instance,
 * as well as the current snapshot of the occupants array,
 * including the old and new index of the occupant.
 * 
 * The given occupant will be included in the given array at the given newIndex.
 * If the location of the occupant didn't change, then the oldIndex and newIndex will be the same.
**/
- (void)xmppRoomMemoryStorage:(XMPPRoomMemoryStorage *)sender
            occupantDidUpdate:(XMPPRoomOccupantMemoryStorageObject *)occupant
                    fromIndex:(NSUInteger)oldIndex
                      toIndex:(NSUInteger)newIndex
                      inArray:(NSArray *)allOccupants;

/**
 * Similar to XMPPRoomDelegate's xmppRoom:didReceiveMessage:fromOccupant: method.
 * 
 * This method provides the delegate with the occupant and message storage instance,
 * as well as the current snapshot of the messages array,
 * including the new index of the message.
 * 
 * The given message will be included in the given array at the given index.
**/
- (void)xmppRoomMemoryStorage:(XMPPRoomMemoryStorage *)sender
			didReceiveMessage:(XMPPRoomMessageMemoryStorageObject *)message
                 fromOccupant:(XMPPRoomOccupantMemoryStorageObject *)occupant
                      atIndex:(NSUInteger)index
                      inArray:(NSArray *)allMessages;

@end
