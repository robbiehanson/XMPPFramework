#import "XMPP.h"
#import "XMPPFramework.h"
#import "XMPPResultSet.h"
#import "XMPPIDTracker.h"

#import "XMPPMessage+XEP_0313.h"

@class XMPPIDTracker;

@protocol XMPPMAM;

@interface XMPPMAM : XMPPModule
{
    XMPPIDTracker *responseTracker;
}

/**
 * Get MAM Messages From XMPP.
 *
 * To Get P2P Chat Messages You Needs to Send IQ with Type Set And You Will Get All Messages
 *
 * But If You Want To Get MUC Message Then You Need To Send IQ to Room JID and then you will get All Messages of That Room.
 *
 * @JID Parameter is User/MUC JID
 * @startTime is The Time From When You Want To Start Getting Archived Messages
 * @endTime is The Time Till You Want To Get Archived Messages
 * @Result is the ResultSet for RSM to Define How Much Result Size You Want
 * @isMUC to Tell You Want MAM Query For P2P or MUC So It Will Make Query For Relevent Type
 *
 *
 **/
- (void)getMAMMessages:(XMPPJID*)jid startTime:(NSDate*)startTime endTime:(NSDate*)endTime resultSet:(XMPPResultSet*)resultSet isMUC:(BOOL)isMUC;

- (NSXMLElement*)getFormField:(NSString*)var withValue:(NSString*)value;

@end


