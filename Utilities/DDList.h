#import <Foundation/Foundation.h>

@class DDListEnumerator;

struct DDListNode {
	void * element;
	struct DDListNode * prev;
	struct DDListNode * next;
};
typedef struct DDListNode DDListNode;


/**
 * The DDList class is designed as a simple list class.
 * It can store objective-c objects as well as non-objective-c pointers.
 * It does not retain objective-c objects as it treats all elements as simple pointers.
 * 
 * Example usages:
 * - Storing a list of delegates, where there is a desire to not retain the individual delegates.
 * - Storing a list of dispatch timers, which are not NSObjects, and cannot be stored in NSCollection classes.
 * 
 * This class is NOT thread-safe.
 * It is designed to be used within a thread-safe context (e.g. within a single dispatch_queue).
**/
@interface DDList : NSObject <NSFastEnumeration>
{
	DDListNode *listHead;
	DDListNode *listTail;
}

- (void)add:(void *)element;
- (void)remove:(void *)element;
- (void)removeAll:(void *)element;
- (void)removeAllElements;

- (BOOL)contains:(void *)element;

- (NSUInteger)count;

/**
 * The enumerators return a snapshot of the list that can be enumerated.
 * The list can later be altered (elements added/removed) without affecting enumerator snapshots.
**/
- (DDListEnumerator *)listEnumerator;
- (DDListEnumerator *)reverseListEnumerator;

@end

@interface DDListEnumerator : NSObject
{
	NSUInteger numElements;
	NSUInteger currentElementIndex;
	void **elements;
}

- (NSUInteger)numTotal;
- (NSUInteger)numLeft;

- (void *)nextElement;

@end
