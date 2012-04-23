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

@property (nonatomic) NSString * serviceType;
@property (nonatomic) NSString * serviceName;
@property (nonatomic) NSString * serviceDomain;
@property (nonatomic) NSString * serviceDescription;

// TXTRecord Properties

@property (nonatomic) NSNumber * status;
@property (nonatomic) NSString * statusMessage;
@property (nonatomic) NSString * firstName;
@property (nonatomic) NSString * lastName;
@property (nonatomic) NSString * nickname;
@property (nonatomic) NSString * displayName;
@property (nonatomic) NSString * lastResolvedAddress;

// Relationship Properties

@property (nonatomic) NSSet * messages;

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
