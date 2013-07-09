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
		[self addChild:[NSXMLElement xmpp_elementWithName:(Name)]];                             \
	}                                                                                           \
	else if (!(Set)) {                                                                          \
		[self removeChildAtIndex:[[self children] indexOfObject:[self xmpp_elementForName:(Name)]]]; \
	}


#define XMPP_VCARD_SET_STRING_CHILD(Value, Name)						\
	NSXMLElement *elem = [self xmpp_elementForName:(Name)];				\
	if ((Value) != nil)                                                 \
	{                                                                   \
		if (elem == nil) {												\
			elem = [NSXMLElement xmpp_elementWithName:(Name)];			\
            [self addChild:elem];                                       \
		}                                                               \
		[elem setStringValue:(Value)];									\
	}                                                                   \
	else if (elem != nil) {											    \
		[self removeChildAtIndex:[[self children] indexOfObject:elem]];	\
	}


#define XMPP_VCARD_SET_N_CHILD(Value, Name)								\
	NSXMLElement *name = [self xmpp_elementForName:@"N"];				\
	if ((Value) != nil && name == nil)                                  \
	{                                                                   \
		name = [NSXMLElement xmpp_elementWithName:@"N"];				\
		[self addChild:name];											\
	}																	\
                                                                        \
	NSXMLElement *part = [name xmpp_elementForName:(Name)];				\
	if ((Value) != nil && part == nil)                                  \
	{								                                    \
		part = [NSXMLElement xmpp_elementWithName:(Name)];				\
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


@interface XMPPvCardTempBase : NSXMLElement <NSCoding, NSCopying> {

}

@end
