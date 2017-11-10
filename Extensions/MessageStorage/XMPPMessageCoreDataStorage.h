#import "XMPPCoreDataStorage.h"

/**
 A client message storage implementation that supports per-module extensibility while maintaining a fixed underlying Core Data model.
 
 The design is based on assigning auxiliary context objects to each stored XMPP message. Those context objects aggregate arbitrary sets of tagged primitive values.
 By defining their own context aggregations and value tags, modules can extend storage capabilities and expose them via a simple API using categories on the core classes.
 
 The application-facing API consists of the main interface and any categories provided by module authors. The protected interface provides module helper methods.
 
 @see XMPPMessageCoreDataStorageObject
 */
@interface XMPPMessageCoreDataStorage : XMPPCoreDataStorage

@end
