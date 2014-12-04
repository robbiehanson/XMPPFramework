//
//  XMPPvCardTempBase.h
//  XEP-0054 vCard-temp
//
//  Created by Eric Chamberlain on 3/9/11.
//  Copyright 2011 RF.com. All rights reserved.
//  Copyright 2010 Martin Morrison. All rights reserved.
//


#import <Foundation/Foundation.h>
#import "NSXMLElement+XMPP.h"


#define XMPP_VCARD_SET_EMPTY_CHILD(Set, Name)                                                   \
	if (Set) {                                                                                  \
		[self addChild:[NSXMLElement elementWithName:(Name)]];                                  \
	}                                                                                           \
	else if (!(Set)) {                                                                          \
		[self removeChildAtIndex:[[self children] indexOfObject:[self elementForName:(Name)]]]; \
	}


#define XMPP_VCARD_SET_STRING_CHILD(Value, Name)						\
	NSXMLElement *elem = [self elementForName:(Name)];					\
	if ((Value) != nil)                                                 \
	{                                                                   \
		if (elem == nil) {												\
			elem = [NSXMLElement elementWithName:(Name)];				\
            [self addChild:elem];                                       \
		}                                                               \
		[elem setStringValue:(Value)];									\
	}                                                                   \
	else if (elem != nil) {											    \
		[self removeChildAtIndex:[[self children] indexOfObject:elem]];	\
	}


#define XMPP_VCARD_SET_N_CHILD(Value, Name)								\
	NSXMLElement *name = [self elementForName:@"N"];					\
	if ((Value) != nil && name == nil)                                  \
	{                                                                   \
		name = [NSXMLElement elementWithName:@"N"];						\
		[self addChild:name];											\
	}																	\
                                                                        \
	NSXMLElement *part = [name elementForName:(Name)];					\
	if ((Value) != nil && part == nil)                                  \
	{								                                    \
		part = [NSXMLElement elementWithName:(Name)];					\
		[name addChild:part];											\
	}																	\
	                                                                    \
	if (Value)                                                          \
	{                                                                   \
		[part setStringValue:(Value)];									\
	}                                                                   \
	else if (part != nil)                                               \
	{                                                                   \
		/* N is mandatory, so we leave it in. */						\
		[name removeChildAtIndex:[[self children] indexOfObject:part]];	\
	}


@interface XMPPvCardTempBase : NSXMLElement <NSSecureCoding, NSCopying> {

}

@end
