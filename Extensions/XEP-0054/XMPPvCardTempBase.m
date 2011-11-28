//
//  XMPPvCardTempBase.m
//  XEP-0054 vCard-temp
//
//  Created by Eric Chamberlain on 3/9/11.
//  Copyright 2011 RF.com. All rights reserved.
//  Copyright 2010 Martin Morrison. All rights reserved.
//

#import "XMPPvCardTempBase.h"

#import <objc/runtime.h>

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

@implementation XMPPvCardTempBase


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark NSCoding protocol
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


#if ! TARGET_OS_IPHONE
- (id)replacementObjectForPortCoder:(NSPortCoder *)encoder
{
	if([encoder isBycopy])
		return self;
	else
		return [super replacementObjectForPortCoder:encoder];
	//	return [NSDistantObject proxyWithLocal:self connection:[encoder connection]];
}
#endif


- (id)initWithCoder:(NSCoder *)coder
{
	NSString *xmlString;
	if([coder allowsKeyedCoding])
	{
		xmlString = [coder decodeObjectForKey:@"xmlString"];
	}
	else
	{
		xmlString = [coder decodeObject];
	}
	
	// The method [super initWithXMLString:error:] may return a different self.
	// In other words, it may [self release], and alloc/init/return a new self.
	// 
	// So to maintain the proper class (XMPPvCardTempEmail, XMPPvCardTempTel, etc)
	// we need to get a reference to the class before invoking super.
	
	Class selfClass = [self class];
	
	if ((self = [super initWithXMLString:xmlString error:nil]))
	{
		object_setClass(self, selfClass);
	}
	return self;
}


- (void)encodeWithCoder:(NSCoder *)coder
{
	NSString *xmlString = [self XMLString];
	
	if([coder allowsKeyedCoding])
	{
		[coder encodeObject:xmlString forKey:@"xmlString"];
	}
	else
	{
		[coder encodeObject:xmlString];
	}
}

- (id)copyWithZone:(NSZone *)zone
{
	NSXMLElement *elementCopy = [super copyWithZone:zone];
	object_setClass(elementCopy, [self class]);
	
	return elementCopy;
}

@end
