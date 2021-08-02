#import <Foundation/Foundation.h>
@import KissXML;

NS_ASSUME_NONNULL_BEGIN
@interface NSXMLElement (XEP_0335)

@property (nonatomic, readonly) NSXMLElement *JSONContainer;

@property (nonatomic, readonly) BOOL isJSONContainer;
@property (nonatomic, readonly) BOOL hasJSONContainer;

@property (nonatomic, readonly) NSString *JSONContainerString;
@property (nonatomic, readonly) NSData *JSONContainerData;
@property (nonatomic, readonly, nullable) id JSONContainerObject;

- (void)addJSONContainerWithString:(NSString *)JSONContainerString;
- (void)addJSONContainerWithData:(NSData *)JSONContainerData;
- (void)addJSONContainerWithObject:(id)JSONContainerObject;

@end
NS_ASSUME_NONNULL_END
