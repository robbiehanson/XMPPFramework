//
//  XMPPvCardTempLabel.m
//  XEP-0054 vCard-temp
//
//  Created by Eric Chamberlain on 3/9/11.
//  Copyright 2011 RF.com. All rights reserved.
//  Copyright 2010 Martin Morrison. All rights reserved.
//


#import "XMPPvCardTempLabel.h"

#import <objc/runtime.h>

#import "DDLog.h"


@implementation XMPPvCardTempLabel


+ (void)initialize {
	// We use the object_setClass method below to dynamically change the class from a standard NSXMLElement.
	// The size of the two classes is expected to be the same.
	// 
	// If a developer adds instance methods to this class, bad things happen at runtime that are very hard to debug.
	// This check is here to aid future developers who may make this mistake.
	// 
	// For Fearless And Experienced Objective-C Developers:
	// It may be possible to support adding instance variables to this class if you seriously need it.
	// To do so, try realloc'ing self after altering the class, and then initialize your variables.
	
	size_t superSize = class_getInstanceSize([NSXMLElement class]);
	size_t ourSize   = class_getInstanceSize([XMPPvCardTempLabel class]);
	
	if (superSize != ourSize)
	{
		DDLogError(@"Adding instance variables to XMPPvCardTempLabel is not currently supported!");
		exit(15);
	}
}


+ (XMPPvCardTempLabel *)vCardLabelFromElement:(NSXMLElement *)elem {
	object_setClass(elem, [XMPPvCardTempLabel class]);
	
	return (XMPPvCardTempLabel *)elem;
}


#pragma mark -
#pragma mark Getter/setter methods


- (NSArray *)lines {
	NSArray *elems = [self elementsForName:@"LINE"];
	NSMutableArray *lines = [[NSMutableArray alloc] initWithCapacity:[elems count]];
	
	for (NSXMLElement *elem in elems) {
		[lines addObject:[elem stringValue]];
	}
	
	NSArray *result = [NSArray arrayWithArray:lines];
	[lines release];
	return result;
}


- (void)setLines:(NSArray *)lines {
	NSArray *elems = [self elementsForName:@"LINE"];
	
	for (NSXMLElement *elem in elems) {
		[self removeChildAtIndex:[[self children] indexOfObject:elem]];
	}
	
	for (NSString *line in lines) {
		NSXMLElement *elem = [NSXMLElement elementWithName:@"LINE"];
		[elem setStringValue:line];
		[self addChild:elem];
	}
}


@end
