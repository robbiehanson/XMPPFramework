#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE
    #import "DDXML.h"
#endif

/**
 * The XMPPResultSet class represents an <set xmlns='http://jabber.org/protocol/rsm'> element form XEP-0059.
 * It extends NSXMLElement.
 *
 * Calling resultSet on an NSXMLElement returns an XMPPResultSet if it exists (see NSXMLElement+XEP_0059.h)
 *
 * This class exists to provide developers an easy way to add functionality to Result Set processing.
 * Simply add your own category to XMPPResultSet to extend it with your own custom methods.
 *
 * XMPPResultSet uses NSNotFound to Specify undefined integer values i.e. max,firstIndex and count.
 * XMPPResultSet uses a NSString of 0 length but not nil to supply empty elements i.e. before and after.
 *
 * Example:
 *
 * To fetch the last 10 items in a result set you need the following XML:
 *
 * <set xmlns='http://jabber.org/protocol/rsm'>
 *  <max>10</max>
 *  <before/>
 * </set>
 *
 * This Result Set can be created by:
 *
 * [XMPPResultSet resultSetWithMax:10 firstIndex:NSNotFound after:nil before:@""];
**/

@interface XMPPResultSet : NSXMLElement

/**
 * Converts an NSXMLElement to an XMPPResultSet element in place (no memory allocations or copying)
 **/
+ (XMPPResultSet *)resultSetFromElement:(NSXMLElement *)element;

/**
 * Creates and returns a new autoreleased XMPPResultSet element.
**/
+ (XMPPResultSet *)resultSet;

+ (XMPPResultSet *)resultSetWithMax:(NSInteger)max;

+ (XMPPResultSet *)resultSetWithMax:(NSInteger)max
                         firstIndex:(NSInteger)index;

+ (XMPPResultSet *)resultSetWithMax:(NSInteger)max
                              after:(NSString *)after;

+ (XMPPResultSet *)resultSetWithMax:(NSInteger)max
                             before:(NSString *)before;

+ (XMPPResultSet *)resultSetWithMax:(NSInteger)max
                         firstIndex:(NSInteger)firstIndex
                              after:(NSString *)after
                             before:(NSString *)before;


/**
 * Creates and returns a new XMPPResultSet element.
**/
- (id)init;

- (id)initWithMax:(NSInteger)max;

- (id)initWithMax:(NSInteger)max
       firstIndex:(NSInteger)firstIndex;

- (id)initWithMax:(NSInteger)max
            after:(NSString *)after;

- (id)initWithMax:(NSInteger)max
           before:(NSString *)before;

- (id)initWithMax:(NSInteger)max
       firstIndex:(NSInteger)firstIndex
            after:(NSString *)after
           before:(NSString *)before;


- (NSInteger)max;

- (NSInteger)firstIndex;

- (NSString *)after;
- (NSString *)before;

- (NSInteger)count;

- (NSString *)first;
- (NSString *)last;

@end
