#import "NSString+XEP_0106.h"

@implementation NSString (XEP_0106)

- (NSString *)jidEscapedString
{
	NSString *jidEscapedString = self;
	
	// XEP-0106: The character sequence \20 MUST NOT be the first or last character of an escaped node identifier.
	jidEscapedString = [jidEscapedString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	
	// \ should only be escaped to \5c if it could be misinterpreted as an escape sequence, so we do this first.
	jidEscapedString = [jidEscapedString stringByReplacingOccurrencesOfString:@"\\5c" withString:@"\\5c5c"];
	jidEscapedString = [jidEscapedString stringByReplacingOccurrencesOfString:@"\\20" withString:@"\\5c\\20"];
	jidEscapedString = [jidEscapedString stringByReplacingOccurrencesOfString:@"\\40" withString:@"\\5c\\40"];
	jidEscapedString = [jidEscapedString stringByReplacingOccurrencesOfString:@"\\3e" withString:@"\\5c\\3e"];
	jidEscapedString = [jidEscapedString stringByReplacingOccurrencesOfString:@"\\3c" withString:@"\\5c\\3c"];
	jidEscapedString = [jidEscapedString stringByReplacingOccurrencesOfString:@"\\3a" withString:@"\\5c\\3a"];
	jidEscapedString = [jidEscapedString stringByReplacingOccurrencesOfString:@"\\2f" withString:@"\\5c\\2f"];
	jidEscapedString = [jidEscapedString stringByReplacingOccurrencesOfString:@"\\27" withString:@"\\5c\\27"];
	jidEscapedString = [jidEscapedString stringByReplacingOccurrencesOfString:@"\\26" withString:@"\\5c\\26"];
	jidEscapedString = [jidEscapedString stringByReplacingOccurrencesOfString:@"\\22" withString:@"\\5c\\22"];
	
	// Escape the charachters
	jidEscapedString = [jidEscapedString stringByReplacingOccurrencesOfString:@" " withString:@"\\20"];
	jidEscapedString = [jidEscapedString stringByReplacingOccurrencesOfString:@"\"" withString:@"\\22"];
	jidEscapedString = [jidEscapedString stringByReplacingOccurrencesOfString:@"&" withString:@"\\26"];
	jidEscapedString = [jidEscapedString stringByReplacingOccurrencesOfString:@"\'" withString:@"\\27"];
	jidEscapedString = [jidEscapedString stringByReplacingOccurrencesOfString:@"/" withString:@"\\2f"];
	jidEscapedString = [jidEscapedString stringByReplacingOccurrencesOfString:@":" withString:@"\\3a"];
	jidEscapedString = [jidEscapedString stringByReplacingOccurrencesOfString:@"<" withString:@"\\3c"];
	jidEscapedString = [jidEscapedString stringByReplacingOccurrencesOfString:@">" withString:@"\\3e"];
	jidEscapedString = [jidEscapedString stringByReplacingOccurrencesOfString:@"@" withString:@"\\40"];

	return jidEscapedString;
}

- (NSString *)jidUnescapedString
{
	NSString *jidUnescapedString = self;
	
	//Unescape the charachters
	jidUnescapedString = [jidUnescapedString stringByReplacingOccurrencesOfString:@"\\20" withString:@" "];
	jidUnescapedString = [jidUnescapedString stringByReplacingOccurrencesOfString:@"\\40" withString:@"@"];
	jidUnescapedString = [jidUnescapedString stringByReplacingOccurrencesOfString:@"\\3e" withString:@">"];
	jidUnescapedString = [jidUnescapedString stringByReplacingOccurrencesOfString:@"\\3c" withString:@"<" ];
	jidUnescapedString = [jidUnescapedString stringByReplacingOccurrencesOfString:@"\\3a" withString:@":"];
	jidUnescapedString = [jidUnescapedString stringByReplacingOccurrencesOfString:@"\\2f" withString:@"/"];
	jidUnescapedString = [jidUnescapedString stringByReplacingOccurrencesOfString:@"\\27" withString:@"\'"];
	jidUnescapedString = [jidUnescapedString stringByReplacingOccurrencesOfString:@"\\26" withString:@"&"];
	jidUnescapedString = [jidUnescapedString stringByReplacingOccurrencesOfString:@"\\22" withString:@"\""];
	jidUnescapedString = [jidUnescapedString stringByReplacingOccurrencesOfString:@"\\5c" withString:@"\\"];

	return jidUnescapedString;
}

@end
