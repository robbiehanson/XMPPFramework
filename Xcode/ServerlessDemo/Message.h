#import <CoreData/CoreData.h>

@class Service;


@interface Message : NSManagedObject

// Properties

@property (nonatomic) NSString * content;
@property (nonatomic) NSNumber * outbound;
@property (nonatomic) NSNumber * read;
@property (nonatomic) NSDate   * timeStamp;

// Relationships

@property (nonatomic) Service * service;

// Convenience Properties

@property (nonatomic, assign) BOOL isOutbound;
@property (nonatomic, assign) BOOL hasBeenRead;

@end
