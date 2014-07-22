//
//  XMPPModule+Subclass.h
//  iPhoneXMPP
//
//  Created by Joao Nunes on 22/07/14.
//
//

#import "XMPPModule.h"

@interface XMPPModule (Subclass)

/**
 * It is recommended that subclasses override this method (instead of activate:)
 * to perform tasks after the module has been activated.
 *
 * This method is only invoked if the module is successfully activated.
 * This method is always invoked on the moduleQueue.
 **/
- (void)didActivate;

@end
