#import "BonjourClient.h"
#import "ServerlessDemoAppDelegate.h"
#import "Service.h"
#import "DDString.h"
#import "DDLog.h"

// Log levels: off, error, warn, info, verbose
static const int ddLogLevel = LOG_LEVEL_VERBOSE;

#define SERVICE_TYPE @"_presence._tcp."


@interface BonjourClient (PrivateAPI)

- (NSDictionary *)dictionaryFromTXTRecordData:(NSData *)txtData;
- (NSData *)txtRecordDataFromDictionary:(NSDictionary *)dict;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation BonjourClient

static BonjourClient *sharedInstance;

+ (void)initialize
{
	static BOOL initialized = NO;
	if(!initialized)
	{
		initialized = YES;
		sharedInstance = [[BonjourClient alloc] init];
	}
}

- (id)init
{
	// Only allow one instance of this class to ever be created
	if(sharedInstance)
	{
		return nil;
	}
	
	if((self = [super init]))
	{
		// Initialize Bonjour NSNetServiceBrowser - this listens for advertised services
		serviceBrowser = [[NSNetServiceBrowser alloc] init];
		[serviceBrowser setDelegate:self];
		
		services = [[NSMutableArray alloc] initWithCapacity:15];
	}
	return self;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Public API
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (BonjourClient *)sharedInstance
{
	return sharedInstance;
}

- (void)startBrowsing
{
	[serviceBrowser searchForServicesOfType:SERVICE_TYPE inDomain:@""];
}

- (void)stopBrowsing
{
	[serviceBrowser stop];
}

- (void)publishServiceOnPort:(UInt16)port
{
    NSString *serviceName = [NSString stringWithFormat:@"demo@%@", [[[UIDevice currentDevice] name] stringByReplacingOccurrencesOfString:@" " withString:@""]];
	localService = [[NSNetService alloc] initWithDomain:@"local." type:SERVICE_TYPE name:serviceName port:port];
	
	[localService setDelegate:self];
	[localService publish];
	
	NSMutableDictionary *mDict = [NSMutableDictionary dictionaryWithCapacity:8];
	
	[mDict setObject:@"1"                forKey:@"txtvers"];
	[mDict setObject:@"Quack"            forKey:@"1st"];
	[mDict setObject:@"Tastic"           forKey:@"last"];
	[mDict setObject:@"Coding"           forKey:@"msg"];
	[mDict setObject:@"dnd"              forKey:@"status"];
	
	[localService setTXTRecordData:[self txtRecordDataFromDictionary:mDict]];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Private API
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSManagedObjectContext *)managedObjectContext
{
	ServerlessDemoAppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
	
	return appDelegate.managedObjectContext;
}

- (NSString *)descriptionForNetService:(NSNetService *)ns
{
	return [NSString stringWithFormat:@"%@.%@%@", [ns name], [ns type], [ns domain]];
}

- (NSDictionary *)dictionaryFromTXTRecordData:(NSData *)txtData
{
	NSDictionary *dict = [NSNetService dictionaryFromTXTRecordData:txtData];
	NSMutableDictionary *mDict = [NSMutableDictionary dictionaryWithCapacity:[dict count]];
	
	// The dictionary all the values encoded in UTF8.
	// So we need to loop through each key/value pair, and convert from the UTF8 data to a string.
	
	for (id key in dict)
	{
		NSData *data = [dict objectForKey:key];
		NSString *str = [NSString stringWithUTF8Data:data];
		
		if (str)
		{
			[mDict setObject:str forKey:key];
		}
		else
		{
			DDLogWarn(@"%@: Unable to get string from key \"%@\"", THIS_FILE, key);
		}
	}
	
	return mDict;
}

- (NSData *)txtRecordDataFromDictionary:(NSDictionary *)dict
{
	NSMutableDictionary *mDict = [NSMutableDictionary dictionaryWithCapacity:[dict count]];
	
	// We need to encode all the values into UTF8.
	
	for (id key in dict)
	{
		NSString *str = [dict objectForKey:key];
		
		if ([str isKindOfClass:[NSString class]])
		{
			NSData *data = [str dataUsingEncoding:NSUTF8StringEncoding];
			
			[mDict setObject:data forKey:key];
		}
		else
		{
			DDLogWarn(@"%@: Value for key \"%@\" is not a string.", THIS_FILE, key);
		}
	}
	
	return [NSNetService dataFromTXTRecordDictionary:mDict];
}

- (Service *)serviceForNetService:(NSNetService *)ns
{
	NSEntityDescription *entity = [NSEntityDescription entityForName:@"Service"
	                                          inManagedObjectContext:[self managedObjectContext]];
	
	NSString *serviceDescription = [self descriptionForNetService:ns];
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"serviceDescription == %@", serviceDescription];
	
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	[fetchRequest setEntity:entity];
	[fetchRequest setPredicate:predicate];
	[fetchRequest setFetchLimit:1];
	
	NSError *error = nil;
	NSArray *results = [[self managedObjectContext] executeFetchRequest:fetchRequest error:&error];
	
	if (results == nil)
	{
		DDLogError(@"%@: Error searching for service \"%@\": %@, %@",
				   THIS_FILE, serviceDescription, error, [error userInfo]);
		
		return nil;
	}
	else if ([results count] == 0)
	{
		DDLogWarn(@"%@: Unable to find service \"%@\"", THIS_FILE, serviceDescription);
		
		return nil;
	}
	else
	{
		return [results objectAtIndex:0];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Bonjour Browsing
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)netServiceBrowser:(NSNetServiceBrowser *)sb didFindService:(NSNetService *)ns moreComing:(BOOL)moreComing
{
	DDLogVerbose(@"%@: netServiceBrowser:didFindService: %@", THIS_FILE, ns);
	
	// Add service to database (if it's not our own service)
	
	if (![ns isEqual:localService])
	{
		Service *service = [NSEntityDescription insertNewObjectForEntityForName:@"Service"
															   inManagedObjectContext:[self managedObjectContext]];
		
		service.serviceType   = [ns type];
		service.serviceName   = [ns name];
		service.serviceDomain = [ns domain];
		service.serviceDescription = [self descriptionForNetService:ns];
		
		[service updateDisplayName];
		
	//	if (!moreComing)
	//	{
			[[self managedObjectContext] save:nil];
	//	}
		
		// Start monitoring the service so we receive TXT Record updates.
		// Note: We must retain the service or it will get deallocated, and we won't receive updates.
		
		[services addObject:ns];
		
		[ns setDelegate:self];
		[ns startMonitoring];
		[ns resolveWithTimeout:10.0];
	}
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)sb didRemoveService:(NSNetService *)ns moreComing:(BOOL)moreComing
{
	Service *service = [self serviceForNetService:ns];
	if (service)
	{
		[[self managedObjectContext] deleteObject:service];
		[[self managedObjectContext] save:nil];
		
		[ns stop];
		[ns stopMonitoring];
		[services removeObject:ns];
	}
}

- (void)netService:(NSNetService *)ns didUpdateTXTRecordData:(NSData *)data
{
	Service *service = [self serviceForNetService:ns];
	if (service)
	{
		NSDictionary *dict = [self dictionaryFromTXTRecordData:data];
		
		// Example:
		// 
		// dict: {
		//     1st        = Robbie;
		//     email      = "robbiehanson@deusty.com";
		//     ext        = 5I;
		//     last       = Hanson;
		//     msg        = Away;
		//     phsh       = ba4d75ea096ee90d1669ff8f4e5d0fade19183af;
		//    "port.p2pj" = 55425;
		//     status     = dnd;
		//     txtvers    = 1;
		//     url        = "";
		//     vc         = "MSDCURA!XN";
		// }
		
		service.nickname  = [dict objectForKey:@"nick"];
		
		service.firstName = [dict objectForKey:@"1st"];
		service.lastName  = [dict objectForKey:@"last"];
		
		[service updateDisplayName];
		
		service.statusType = [Service statusTypeForStatusTxtTitle:[dict objectForKey:@"status"]];
		service.statusMessage = [dict objectForKey:@"msg"];
		
		[[self managedObjectContext] save:nil];
	}
}

- (void)netServiceDidResolveAddress:(NSNetService *)ns
{
	Service *service = [self serviceForNetService:ns];
	if (service)
	{
		ServerlessDemoAppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
		NSData *address = [appDelegate IPv4AddressFromAddresses:[ns addresses]];
		NSString *addrStr = [appDelegate stringFromAddress:address];
		
		DDLogVerbose(@"%@: ns(%@) -> %@", THIS_FILE, [self descriptionForNetService:ns], addrStr);
		
		service.lastResolvedAddress = addrStr;
		
		[[self managedObjectContext] save:nil];
	}
	
	[ns stop];
}

- (void)netService:(NSNetService *)ns didNotResolve:(NSDictionary *)errorDict
{
	DDLogVerbose(@"%@: netService:%@ didNotResolve:%@", THIS_FILE, ns, errorDict);
	
	[ns stop];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Bonjour Publishing
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)netServiceDidPublish:(NSNetService *)sender
{
	DDLogVerbose(@"%@: netServiceDidPublish", THIS_FILE);
}

- (void)netService:(NSNetService *)sender didNotPublish:(NSDictionary *)errorDict
{
	DDLogVerbose(@"%@: netService:didNotPublish: %@", THIS_FILE, errorDict);
}

@end
