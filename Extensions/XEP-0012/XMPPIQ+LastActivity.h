//
//  XMPPIQ+LastActivity.h
//  ArgelaIMPS
//
//  Created by Tolga Tanriverdi on 8/8/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "XMPPIQ.h"

@interface XMPPIQ (LastActivity)
+(XMPPIQ *) queryLastActivityOf:(XMPPJID*)jid;
-(BOOL) hasLastActivity;
-(NSDate*) lastActivityTime;
-(NSString*) lastActivityFrom;
-(BOOL) hasStatusMessage;
-(NSString*)statusMessage;
@end
