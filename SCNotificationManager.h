/*
 * Written by Theo Hultberg (theo@iconara.net) 2004-03-09 with help from Boaz Stuller.
 * This code is in the public domain, provided that this notice remains.
 */

#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>


/*!
 * @class          SCNotificationManager
 * @abstract       Listens for changes in the system configuration database
 *                 and posts the changes to the default notification center.
 * @discussion     To get notifications when the key "State:/Network/Global/IPv4"
 *                 changes, register yourself as an observer for notifications
 *                 with the name "State:/Network/Global/IPv4".
 *                 If you want to recieve notifications on any change in the
 *                 system configuration databse, register for notifications
 *                 on the SCNotificationManager object.
 *                 The user info in the notification is the data in the database
 *                 for the key you listen for.
 */
@interface SCNotificationManager : NSObject
{
	SCDynamicStoreRef dynStore;
	CFRunLoopSourceRef rlSrc;
}

@end


/*!
 * @function       _SCNotificationCallback
 * @abstract       Callback for the dynamic store, just calls keysChanged: on 
 *                 the notification center.
 */
void _SCNotificationCallback(SCDynamicStoreRef store, CFArrayRef changedKeys, void *info);
