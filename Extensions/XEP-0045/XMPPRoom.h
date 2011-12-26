#import <Foundation/Foundation.h>
#import "XMPP.h"
#import "XMPPRoomMessage.h"
#import "XMPPRoomOccupant.h"

@class XMPPIDTracker;
@protocol XMPPRoomStorage;
@protocol XMPPRoomDelegate;


@interface XMPPRoom : XMPPModule
{
/*	Inherited from XMPPModule:
	
	XMPPStream *xmppStream;
 
	dispatch_queue_t moduleQueue;
	id multicastDelegate;
 */
 
 	__strong id <XMPPRoomStorage> xmppRoomStorage;
 	
	__strong XMPPJID *roomJID;
	
	__strong XMPPJID *myRoomJID;
	__strong NSString *myNickname;
	
	__strong NSString *roomSubject;
	
	XMPPIDTracker *responseTracker;
	
	uint16_t state;
}

- (id)initWithRoomStorage:(id <XMPPRoomStorage>)storage jid:(XMPPJID *)roomJID;
- (id)initWithRoomStorage:(id <XMPPRoomStorage>)storage jid:(XMPPJID *)roomJID dispatchQueue:(dispatch_queue_t)queue;

/* Inherited from XMPPModule:

- (BOOL)activate:(XMPPStream *)xmppStream;
- (void)deactivate;

@property (readonly) XMPPStream *xmppStream;

- (void)addDelegate:(id)delegate delegateQueue:(dispatch_queue_t)delegateQueue;
- (void)removeDelegate:(id)delegate delegateQueue:(dispatch_queue_t)delegateQueue;
- (void)removeDelegate:(id)delegate;

- (NSString *)moduleName;
 
*/

@property (readonly) id <XMPPRoomStorage> xmppRoomStorage;

@property (readonly) XMPPJID * roomJID;     // E.g. xmpp-development@conference.deusty.com

@property (readonly) XMPPJID * myRoomJID;   // E.g. xmpp-development@conference.deusty.com/robbiehanson
@property (readonly) NSString * myNickname; // E.g. robbiehanson

@property (readonly) NSString *roomSubject;

@property (readonly) BOOL isJoined;

/**
 * Sends a presence element to the join room, and indicating desire to create the room if it doesn't already exist.
 * 
 * If the room did not already exist, and the authenticated user is allowed to create the room,
 * then the xmppRoomDidCreate: delegate method will be invoked.
 * At this point you'll need to configure the room before others can join.
 * 
 * If the room already exists, then the xmppRoomDidJoin: delegate method will be invoked.
 * 
 * @see fetchConfigurationForm
 * @see configureRoomUsingOptions:
**/
- (void)createOrJoinRoomUsingNickname:(NSString *)desiredNickname;

/**
 * Sends a presence element to join the room.
 * If successful, the xmppRoomDidJoin: delegate method will be invoked.
**/
- (void)joinRoomUsingNickname:(NSString *)desiredNickname;

/**
 * There are two ways to configure a room.
 * 1.) Accept the default configuration
 * 2.) Send a custom configuration
 * 
 * To see which configuration options the server supports,
 * or to inspect the default options, you'll need to fetch the configuration form.
 * 
 * @see configureRoomUsingOptions:
**/
- (void)fetchConfigurationForm;

/**
 * Pass nil to accept the default configuration.
**/
- (void)configureRoomUsingOptions:(NSXMLElement *)roomConfigForm;

- (void)leaveRoom;
- (void)destoryRoom;

- (void)chageNickname:(NSString *)newNickname;
- (void)changeRoomSubject:(NSString *)newRoomSubject;

- (void)inviteUser:(XMPPJID *)jid withMessage:(NSString *)invitationMessage;

- (void)sendMessage:(NSString *)msg;

- (void)fetchBanList;
- (void)fetchMembersList;
- (void)fetchModeratorsList;

/**
 * The ban list, member list, and moderator list are simply subsets of the room privileges list.
 * That is, a user's status as 'banned', 'member', 'moderator', etc,
 * are simply different priveleges that may be assigned to a user.
 * 
 * You may edit the list of privileges using this method.
 * The array of items corresponds with the <item/> stanzas of Section 9 of XEP-0045.
 * This class provides helper methods to create these item elements.
 * 
 * @see itemWithAffiliation:jid:
 * @see itemWithRole:jid:
 * 
 * The authenticated user must be an admin or owner of the room, or the server will deny the request.
**/
- (void)editRoomPrivileges:(NSArray *)items;

+ (NSXMLElement *)itemWithAffiliation:(NSString *)affiliation jid:(XMPPJID *)jid;
+ (NSXMLElement *)itemWithRole:(NSString *)role jid:(XMPPJID *)jid;

@end

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol XMPPRoomStorage <NSObject>
@required

// 
// 
// -- PUBLIC METHODS --
// 
// There are no public methods required by this protocol.
// 
// Each individual storage class will provide a proper way to access/enumerate the
// occupants/messages according to the underlying storage mechanism.
// 


// 
// 
// -- PRIVATE METHODS --
// 
// These methods are designed to be used ONLY by the XMPPRoom class.
// 
// 

/**
 * Configures the storage class, passing it's parent and parent's dispatch queue.
 * 
 * This method is called by the init method of the XMPPRoom class.
 * This method is designed to inform the storage class of it's parent
 * and of the dispatch queue the parent will be operating on.
 * 
 * A storage class may choose to operate on the same queue as it's parent,
 * as the majority of the time it will be getting called by the parent.
 * If both are operating on the same queue, the combination may run faster.
 * 
 * Some storage classes support multiple xmppStreams,
 * and may choose to operate on their own internal queue.
 * 
 * This method should return YES if it was configured properly.
 * It should return NO only if configuration failed.
 * For example, a storage class designed to be used only with a single xmppStream is being added to a second stream.
 * The XMPPCapabilites class is configured to ignore the passed
 * storage class in it's init method if this method returns NO.
**/
- (BOOL)configureWithParent:(XMPPRoom *)aParent queue:(dispatch_queue_t)queue;

/**
 * Updates and returns the occupant for the given presence element.
 * If the presence type is "available", and the occupant doesn't already exist, then one should be created.
**/
- (void)handlePresence:(XMPPPresence *)presence room:(XMPPRoom *)room;

/**
 * Stores or otherwise handles the given message element.
**/
- (void)handleIncomingMessage:(XMPPMessage *)message room:(XMPPRoom *)room;
- (void)handleOutgoingMessage:(XMPPMessage *)message room:(XMPPRoom *)room;

@optional

- (void)handleDidJoinRoom:(XMPPJID *)roomJID withNickname:(NSString *)nickname;
- (void)handleDidLeaveRoom:(XMPPJID *)roomJID;

@end

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol XMPPRoomDelegate <NSObject>
@optional

- (void)xmppRoomDidCreate:(XMPPRoom *)sender;

/**
 * Invoked with the results of a request to fetch the configuration form.
 * The given config form will look something like:
 * 
 * <x xmlns='jabber:x:data' type='form'>
 *   <title>Configuration for MUC Room</title>
 *   <field type='hidden'
 *           var='FORM_TYPE'>
 *     <value>http://jabber.org/protocol/muc#roomconfig</value>
 *   </field>
 *   <field label='Natural-Language Room Name'
 *           type='text-single'
 *            var='muc#roomconfig_roomname'/>
 *   <field label='Enable Public Logging?'
 *           type='boolean'
 *            var='muc#roomconfig_enablelogging'>
 *     <value>0</value>
 *   </field>
 *   ...
 * </x>
 * 
 * The form is to be filled out and then submitted via the configureRoomUsingOptions: method.
 * 
 * @see fetchConfigurationForm:
 * @see configureRoomUsingOptions:
**/
- (void)xmppRoom:(XMPPRoom *)sender didFetchConfigurationForm:(NSXMLElement *)configForm;

- (void)xmppRoom:(XMPPRoom *)sender willSendConfiguration:(XMPPIQ *)roomConfigForm;
- (void)xmppRoomDidConfigure:(XMPPRoom *)sender;

- (void)xmppRoomDidJoin:(XMPPRoom *)sender;
- (void)xmppRoomDidLeave:(XMPPRoom *)sender;

- (void)xmppRoom:(XMPPRoom *)sender occupantDidJoin:(XMPPJID *)occupantJID withPresence:(XMPPPresence *)presence;
- (void)xmppRoom:(XMPPRoom *)sender occupantDidLeave:(XMPPJID *)occupantJID withPresence:(XMPPPresence *)presence;
- (void)xmppRoom:(XMPPRoom *)sender occupantDidUpdate:(XMPPJID *)occupantJID withPresence:(XMPPPresence *)presence;

/**
 * Invoked when a message is received.
 * The occupant parameter may be nil if the message came directly from the room, or from a non-occupant.
**/
- (void)xmppRoom:(XMPPRoom *)sender didReceiveMessage:(XMPPMessage *)message fromOccupant:(XMPPJID *)occupantJID;

- (void)xmppRoom:(XMPPRoom *)sender didFetchBanList:(NSArray *)items;
- (void)xmppRoom:(XMPPRoom *)sender didNotFetchBanList:(XMPPIQ *)iqError;

- (void)xmppRoom:(XMPPRoom *)sender didFetchMembersList:(NSArray *)items;
- (void)xmppRoom:(XMPPRoom *)sender didNotFetchMembersList:(XMPPIQ *)iqError;

- (void)xmppRoom:(XMPPRoom *)sender didFetchModeratorsList:(NSArray *)items;
- (void)xmppRoom:(XMPPRoom *)sender didNotFetchModeratorsList:(XMPPIQ *)iqError;

- (void)xmppRoomDidEditPrivileges:(XMPPRoom *)sender;
- (void)xmppRoom:(XMPPRoom *)sender didNotEditPrivileges:(XMPPIQ *)iqError;

@end
