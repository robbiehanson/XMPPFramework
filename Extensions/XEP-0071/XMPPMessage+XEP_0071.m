//
//  XMPPMessage+XEP_0071.m
//
//  Created by Indragie Karunaratne on 2013-01-08.
//  Copyright (c) 2013 Indragie Karunaratne. All rights reserved.
//

#import "XMPPMessage+XEP_0071.h"

static NSString* const XMPPMessageElementBody = @"body";
static NSString* const XMPPMessageElementNSBody = @"http://www.w3.org/1999/xhtml";
static NSString* const XMPPMessageElementHTML = @"html";
static NSString* const XMPPMessageElementNSHTML = @"http://jabber.org/protocol/xhtml-im";

@interface NSColor (HexColors)
// Code rom this Apple technote <http://developer.apple.com/library/mac/#qa/qa1576/_index.html>
- (NSString *)xmpp_hexadecimalValue;
@end

@implementation XMPPMessage (XEP_0071)
- (NSAttributedString *)attributedBody
{
	NSXMLElement *html = [self elementForName:XMPPMessageElementHTML xmlns:XMPPMessageElementNSHTML];
	NSXMLElement *body = [html elementForName:XMPPMessageElementBody xmlns:XMPPMessageElementNSBody];
	if (body) {
		NSString *HTMLString = [body XMLString];
		NSStringEncoding encoding = [HTMLString fastestEncoding];
		NSData *data = [HTMLString dataUsingEncoding:encoding];
		if (data)
			return [[NSAttributedString alloc] initWithHTML:data
													options:@{NSCharacterEncodingDocumentAttribute : @(encoding)}
										 documentAttributes:NULL];
	}
	return nil;
}

- (void)setAttributedBody:(NSAttributedString *)attributedBody
{
	NSXMLElement *html = [self elementForName:XMPPMessageElementHTML xmlns:XMPPMessageElementNSHTML];
	if (!html) {
		html = [NSXMLElement elementWithName:XMPPMessageElementHTML xmlns:XMPPMessageElementNSHTML];
		[self addChild:html];
	}
	NSXMLElement *body = [html elementForName:XMPPMessageElementBody xmlns:XMPPMessageElementNSBody];
	if (!body) {
		body = [NSXMLElement elementWithName:XMPPMessageElementBody xmlns:XMPPMessageElementNSBody];
		[html addChild:body];
	}
	[body setChildren:nil]; // Remove all existing HTML
	NSString *rawString = [attributedBody string];
	[attributedBody enumerateAttributesInRange:NSMakeRange(0, [attributedBody length]) options:0 usingBlock:^(NSDictionary *attrs, NSRange range, BOOL *stop) {
		NSXMLElement *span = [NSXMLElement elementWithName:@"span" stringValue:[rawString substringWithRange:range]];
		NSString *style = [[self class] styleForAttributes:attrs];
		if ([style length])
			[span addAttributeWithName:@"style" stringValue:style];
		[body addChild:span];
	}];
	self.body = [attributedBody string];
}

+ (NSString *)styleForAttributes:(NSDictionary *)attr
{
	NSMutableString *style = [NSMutableString string];
	NSFont *font = [attr objectForKey:NSFontAttributeName];
	if (font) {
		[style appendFormat:@"font-family: %@;", [font familyName]];
		[style appendFormat:@"font-size: %ldpt", (NSInteger)[font pointSize]];
		NSFontTraitMask traits = [[NSFontManager sharedFontManager] traitsOfFont:font];
		if (traits & NSItalicFontMask) {
			[style appendString:@"font-style: italic;"];
		}
		if (traits & NSBoldFontMask) {
			[style appendString:@"font-weight: bold;"];
		}
	}
	NSColor *foregroundColor = [attr objectForKey:NSForegroundColorAttributeName];
	if (foregroundColor) {
		NSString *colorString = [foregroundColor xmpp_hexadecimalValue];
		if (colorString) {
			[style appendFormat:@"color: %@;", colorString];
		}
	}
	NSColor *backgroundColor = [attr objectForKey:NSBackgroundColorAttributeName];
	if (backgroundColor) {
		NSString *colorString = [backgroundColor xmpp_hexadecimalValue];
		if (colorString) {
			[style appendFormat:@"background-color: %@;", colorString];
		}
	}
	NSParagraphStyle *paragraphStyle = [attr objectForKey:NSParagraphStyleAttributeName];
	if (paragraphStyle) {
		NSTextAlignment alignment = [paragraphStyle alignment];
		NSString *alignmentString = nil;
		switch (alignment) {
			case NSLeftTextAlignment:
				alignmentString = @"left";
				break;
			case NSCenterTextAlignment:
				alignmentString = @"center";
				break;
			case NSRightTextAlignment:
				alignmentString = @"right";
				break;
			default:
				break;
		}
		if (alignmentString) {
			[style appendFormat:@"text-align: %@;", alignmentString];
		}
	}
	NSInteger underline = [[attr objectForKey:NSUnderlineStyleAttributeName] integerValue];
	if (underline != 0) {
		[style appendString:@"text-decoration: underline;"];
	}
	NSInteger strikethrough = [[attr objectForKey:NSStrikethroughStyleAttributeName] integerValue];
	if (strikethrough != 0) {
		[style appendString:@"text-decoration: line-through;"];
	}
	return style;
}
@end

@implementation NSColor (HexColors)
- (NSString *)xmpp_hexadecimalValue
{
	CGFloat redFloatValue, greenFloatValue, blueFloatValue;
    int redIntValue, greenIntValue, blueIntValue;
    NSString *redHexValue, *greenHexValue, *blueHexValue;
	
	// Convert the NSColor to the RGB color space before we can access its components
    NSColor *convertedColor = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	
    if(convertedColor) {
        // Get the red, green, and blue components of the color
        [convertedColor getRed:&redFloatValue green:&greenFloatValue blue:&blueFloatValue alpha:NULL];
        // Convert the components to numbers (unsigned decimal integer) between 0 and 255
        redIntValue = redFloatValue * 255.99999f;
        greenIntValue = greenFloatValue * 255.99999f;
        blueIntValue = blueFloatValue * 255.99999f;
		
        // Convert the numbers to hex strings
        redHexValue = [NSString stringWithFormat:@"%02x", redIntValue];
        greenHexValue = [NSString stringWithFormat:@"%02x", greenIntValue];
        blueHexValue = [NSString stringWithFormat:@"%02x", blueIntValue];
		
        // Concatenate the red, green, and blue components' hex strings together with a "#"
        return [NSString stringWithFormat:@"#%@%@%@", redHexValue, greenHexValue, blueHexValue];
    }
    return nil;
}
@end
