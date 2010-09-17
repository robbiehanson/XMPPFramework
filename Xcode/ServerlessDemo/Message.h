#import <CoreData/CoreData.h>

@class Service;


@interface Message : NSManagedObject

// Properties

@property (nonatomic, retain) NSString * content;
@property (nonatomic, retain) NSNumber * outbound;
@property (nonatomic, retain) NSNumber * read;
@property (nonatomic, retain) NSDate   * timeStamp;

// Relationships

@property (nonatomic, retain) Service * service;

// Convenience Properties

@property (nonatomic, assign) BOOL isOutbound;
@property (nonatomic, assign) BOOL hasBeenRead;

@end
