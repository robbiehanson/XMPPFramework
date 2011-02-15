#import <CoreData/CoreData.h>

enum StatusType
{
	StatusOffline   = 0,
	StatusDND       = 1,
	StatusAvailable = 2,
};
typedef enum StatusType StatusType;


@interface Service : NSManagedObject

// NSNetService Properties

@property (nonatomic, retain) NSString * serviceType;
@property (nonatomic, retain) NSString * serviceName;
@property (nonatomic, retain) NSString * serviceDomain;
@property (nonatomic, retain) NSString * serviceDescription;

// TXTRecord Properties

@property (nonatomic, retain) NSNumber * status;
@property (nonatomic, retain) NSString * statusMessage;
@property (nonatomic, retain) NSString * firstName;
@property (nonatomic, retain) NSString * lastName;
@property (nonatomic, retain) NSString * nickname;
@property (nonatomic, retain) NSString * displayName;
@property (nonatomic, retain) NSString * lastResolvedAddress;

// Relationship Properties

@property (nonatomic, retain) NSSet * messages;

// Convenience Properties

@property (nonatomic, assign) StatusType statusType;

// Utility Methods

+ (NSString *)statusTxtTitleForStatusType:(StatusType)type;
+ (NSString *)statusDisplayTitleForStatusType:(StatusType)type;

+ (StatusType)statusTypeForStatusTxtTitle:(NSString *)statusTxtTitle;

- (NSString *)statusTxtTitle;
- (NSString *)statusDisplayTitle;

- (void)updateDisplayName;

- (NSUInteger)numberOfUnreadMessages;

@end
