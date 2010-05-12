#import "TestCapabilitiesHashingAppDelegate.h"
#import "NSDataAdditions.h"
#import "NSXMLElementAdditions.h"


@implementation TestCapabilitiesHashingAppDelegate

#if TARGET_OS_IPHONE
  @synthesize window;
  @synthesize viewController;
#else
  @synthesize window;
#endif

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Hashing
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

NSString* encodeLt(NSString *str)
{
	// From the RFC:
	// 
	// If the string "&lt;" appears in any of the hash values,
	// then that value MUST NOT convert it to "<" because
	// completing such a conversion would open the protocol to trivial attacks.
	// 
	// All of the XML libraries perform this conversion for us automatically (which makes sense).
	// Furthermore, it is illegal for an attribute or namespace value to have a raw "<" character (as per XML).
	// So the solution is very simple:
	// Just convert any '<' characters to the escaped "&lt;" string.
	
	return [str stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
}

NSInteger sortIdentities(NSXMLElement *identity1, NSXMLElement *identity2, void *context)
{
	// Sort the service discovery identities by category and then by type and then by xml:lang (if it exists).
	// 
	// All sort operations MUST be performed using "i;octet" collation as specified in Section 9.3 of RFC 4790.
	
	NSComparisonResult result;
	
	NSString *category1 = [identity1 attributeStringValueForName:@"category" withDefaultValue:@""];
	NSString *category2 = [identity2 attributeStringValueForName:@"category" withDefaultValue:@""];
	
	category1 = encodeLt(category1);
	category2 = encodeLt(category2);
	
	result = [category1 compare:category2 options:NSLiteralSearch];
	if (result != NSOrderedSame)
	{
		return result;
	}
	
	NSString *type1 = [identity1 attributeStringValueForName:@"type" withDefaultValue:@""];
	NSString *type2 = [identity2 attributeStringValueForName:@"type" withDefaultValue:@""];
	
	type1 = encodeLt(type1);
	type2 = encodeLt(type2);
	
	result = [type1 compare:type2 options:NSLiteralSearch];
	if (result != NSOrderedSame)
	{
		return result;
	}
	
	NSString *lang1 = [identity1 attributeStringValueForName:@"xml:lang" withDefaultValue:@""];
	NSString *lang2 = [identity2 attributeStringValueForName:@"xml:lang" withDefaultValue:@""];
	
	lang1 = encodeLt(lang1);
	lang2 = encodeLt(lang2);
	
	result = [lang1 compare:lang2 options:NSLiteralSearch];
	if (result != NSOrderedSame)
	{
		return result;
	}
	
	NSString *name1 = [identity1 attributeStringValueForName:@"name" withDefaultValue:@""];
	NSString *name2 = [identity2 attributeStringValueForName:@"name" withDefaultValue:@""];
	
	name1 = encodeLt(name1);
	name2 = encodeLt(name2);
	
	return [name1 compare:name2 options:NSLiteralSearch];
}

NSInteger sortFeatures(NSXMLElement *feature1, NSXMLElement *feature2, void *context)
{
	// All sort operations MUST be performed using "i;octet" collation as specified in Section 9.3 of RFC 4790.
	
	NSString *var1 = [feature1 attributeStringValueForName:@"var" withDefaultValue:@""];
	NSString *var2 = [feature2 attributeStringValueForName:@"var" withDefaultValue:@""];
	
	var1 = encodeLt(var1);
	var2 = encodeLt(var2);
	
	return [var1 compare:var2 options:NSLiteralSearch];
}

NSString* extractFormTypeValue(NSXMLElement *form)
{
	// From the RFC:
	// 
	// If the FORM_TYPE field is not of type "hidden" or the form does not
	// include a FORM_TYPE field, ignore the form but continue processing.
	// 
	// If the FORM_TYPE field contains more than one <value/> element with different XML character data,
	// consider the entire response to be ill-formed.
	
	// This method will return:
	// 
	// - The form type's value if it exists
	// - An empty string if it does not contain a form type field (or the form type is not of type hidden)
	// - Nil if the form type is invalid (contains more than one <value/> element which are different)
	// 
	// In other words
	// 
	// - Non-empty string -> proper form
	// - Empty string -> ignore form
	// - Nil -> Entire response is to be considered ill-formed
	// 
	// The returned value is properly encoded via encodeLt() and contains the trailing '<' character.
	
	NSArray *fields = [form elementsForName:@"field"];
	for (NSXMLElement *field in fields)
	{
		NSString *var = [field attributeStringValueForName:@"var"];
		NSString *type = [field attributeStringValueForName:@"type"];
		
		if ([var isEqualToString:@"FORM_TYPE"] && [type isEqualToString:@"hidden"])
		{
			NSArray *values = [field elementsForName:@"value"];
			
			if ([values count] > 0)
			{
				if ([values count] > 1)
				{
					NSString *baseValue = [[values objectAtIndex:0] stringValue];
					
					NSUInteger i;
					for (i = 1; i < [values count]; i++)
					{
						NSString *value = [[values objectAtIndex:i] stringValue];
						
						if (![value isEqualToString:baseValue])
						{
							// Multiple <value/> elements with differing XML character data
							return nil;
						}
					}
				}
				
				NSString *result = [[values lastObject] stringValue];
				if (result == nil)
				{
					// This is why the result contains the trailing '<' character.
					result = @"";
				}
				
				return [NSString stringWithFormat:@"%@<", encodeLt(result)];
			}
		}
	}
	
	return @"";
}

NSInteger sortForms(NSXMLElement *form1, NSXMLElement *form2, void *context)
{
	// Sort the forms by the FORM_TYPE (i.e., by the XML character data of the <value/> element.
	// 
	// All sort operations MUST be performed using "i;octet" collation as specified in Section 9.3 of RFC 4790.
	
	NSString *formTypeValue1 = extractFormTypeValue(form1);
	NSString *formTypeValue2 = extractFormTypeValue(form2);
	
	// The formTypeValue variable is guaranteed to be properly encoded.
	
	return [formTypeValue1 compare:formTypeValue2 options:NSLiteralSearch];
}

NSInteger sortFormFields(NSXMLElement *field1, NSXMLElement *field2, void *context)
{
	// Sort the fields by the "var" attribute.
	// 
	// All sort operations MUST be performed using "i;octet" collation as specified in Section 9.3 of RFC 4790.
	
	NSString *var1 = [field1 attributeStringValueForName:@"var" withDefaultValue:@""];
	NSString *var2 = [field2 attributeStringValueForName:@"var" withDefaultValue:@""];
	
	var1 = encodeLt(var1);
	var2 = encodeLt(var2);
	
	return [var1 compare:var2 options:NSLiteralSearch];
}

NSInteger sortFieldValues(NSXMLElement *value1, NSXMLElement *value2, void *context)
{
	NSString *str1 = [value1 stringValue];
	NSString *str2 = [value2 stringValue];
	
	if (str1 == nil) str1 = @"";
	if (str2 == nil) str2 = @"";
	
	str1 = encodeLt(str1);
	str2 = encodeLt(str2);
	
	return [str1 compare:str2 options:NSLiteralSearch];
}

- (NSString *)hashCapabilities:(NSXMLElement *)iq
{
	NSXMLElement *query = [iq elementForName:@"query"];
	if (query == nil) return nil;
	
	NSMutableSet *set = [NSMutableSet set];
	
	NSMutableString *s = [NSMutableString string];
	
	NSArray *identities = [[query elementsForName:@"identity"] sortedArrayUsingFunction:sortIdentities context:NULL];
	for (NSXMLElement *identity in identities)
	{
		// Format as: category / type / lang / name
		
		NSString *category = [identity attributeStringValueForName:@"category" withDefaultValue:@""];
		NSString *type     = [identity attributeStringValueForName:@"type"     withDefaultValue:@""];
		NSString *lang     = [identity attributeStringValueForName:@"xml:lang" withDefaultValue:@""];
		NSString *name     = [identity attributeStringValueForName:@"name"     withDefaultValue:@""];
		
		category = encodeLt(category);
		type     = encodeLt(type);
		lang     = encodeLt(lang);
		name     = encodeLt(name);
		
		NSString *mash = [NSString stringWithFormat:@"%@/%@/%@/%@<", category, type, lang, name];
		
		// Section 5.4, rule 3.3:
		// 
		// If the response includes more than one service discovery identity with
		// the same category/type/lang/name, consider the entire response to be ill-formed.
		
		if ([set containsObject:mash])
		{
			return nil;
		}
		else
		{
			[set addObject:mash];
		}
		
		[s appendString:mash];
	}
	
	[set removeAllObjects];
	
	
	NSArray *features = [[query elementsForName:@"feature"] sortedArrayUsingFunction:sortFeatures context:NULL];
	for (NSXMLElement *feature in features)
	{
		NSString *var = [feature attributeStringValueForName:@"var" withDefaultValue:@""];
		
		var = encodeLt(var);
		
		NSString *mash = [NSString stringWithFormat:@"%@<", var];
		
		// Section 5.4, rule 3.4:
		// 
		// If the response includes more than one service discovery feature with the
		// same XML character data, consider the entire response to be ill-formed.
		
		if ([set containsObject:mash])
		{
			return nil;
		}
		else
		{
			[set addObject:mash];
		}
		
		[s appendString:mash];
	}
	
	[set removeAllObjects];
	
	NSArray *unsortedForms = [query elementsForLocalName:@"x" URI:@"jabber:x:data"];
	NSArray *forms = [unsortedForms sortedArrayUsingFunction:sortForms context:NULL];
	for (NSXMLElement *form in forms)
	{
		NSString *formTypeValue = extractFormTypeValue(form);
		
		if (formTypeValue == nil)
		{
			// Invalid according to section 5.4, rule 3.5
			return nil;
		}
		if ([formTypeValue length] == 0)
		{
			// Ignore according to section 5.4, rule 3.6
			continue;
		}
		
		// Note: The formTypeValue is properly encoded and contains the trailing '<' character.
		
		[s appendString:formTypeValue];
		
		NSArray *fields = [[form elementsForName:@"field"] sortedArrayUsingFunction:sortFormFields context:NULL];
		for (NSXMLElement *field in fields)
		{
			// For each field other than FORM_TYPE:
			// 
			// 1. Append the value of the var attribute, followed by the '<' character.
			// 2. Sort values by the XML character data of the <value/> element.
			// 3. For each <value/> element, append the XML character data, followed by the '<' character.
			
			NSString *var = [field attributeStringValueForName:@"var" withDefaultValue:@""];
			
			var = encodeLt(var);
			
			if ([var isEqualToString:@"FORM_TYPE"])
			{
				continue;
			}
			
			[s appendFormat:@"%@<", var];
			
			NSArray *values = [[field elementsForName:@"value"] sortedArrayUsingFunction:sortFieldValues context:NULL];
			for (NSXMLElement *value in values)
			{
				NSString *str = [value stringValue];
				if (str == nil)
				{
					str = @"";
				}
				
				str = encodeLt(str);
				
				[s appendFormat:@"%@<", str];
			}
		}
	}
	
	NSLog(@"Verification string: %@", s);
	
	NSData *data = [s dataUsingEncoding:NSUTF8StringEncoding];
	NSData *hash = [data sha1Digest];
	
	return [hash base64Encoded];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Testing
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)test1
{
	NSLog(@"============================================================");
	
	// From XEP-0115, Section 5.2
	
	NSMutableString *s = [NSMutableString string];
	[s appendString:@"<iq from='romeo@montague.lit/orchard' type='result'>"];
	[s appendString:@"  <query xmlns='http://jabber.org/protocol/disco#info'>"];
	[s appendString:@"    <identity category='client' name='Exodus 0.9.1' type='pc'/>"];
	[s appendString:@"    <feature var='http://jabber.org/protocol/caps'/>"];
	[s appendString:@"    <feature var='http://jabber.org/protocol/disco#info'/>"];
	[s appendString:@"    <feature var='http://jabber.org/protocol/disco#items'/>"];
	[s appendString:@"    <feature var='http://jabber.org/protocol/muc'/>"];
	[s appendString:@"  </query>"];
	[s appendString:@"</iq>"];
	
	NSXMLDocument *doc = [[[NSXMLDocument alloc] initWithXMLString:s options:0 error:nil] autorelease];
	
	NSXMLElement *iq = [doc rootElement];
//	NSLog(@"iq:\n%@", [iq XMLStringWithOptions:(NSXMLNodeCompactEmptyElement | NSXMLNodePrettyPrint)]);
	
	NSLog(@"test1 result   : %@", [self hashCapabilities:iq]);
	NSLog(@"expected result: QgayPKawpkPSDYmwT/WM94uAlu0=");
	
	NSLog(@"============================================================");
}

- (void)test2
{
	NSLog(@"============================================================");
	
	// From XEP-0115, Section 5.3
	
	NSMutableString *s = [NSMutableString string];
	[s appendString:@"<iq from='benvolio@capulet.lit/230193' type='result'>"];
	[s appendString:@"  <query xmlns='http://jabber.org/protocol/disco#info'>"];
	[s appendString:@"    <identity xml:lang='en' category='client' name='Psi 0.11' type='pc'/>"];
	[s appendString:@"    <identity xml:lang='el' category='client' name='Ψ 0.11' type='pc'/>"];
	[s appendString:@"    <feature var='http://jabber.org/protocol/caps'/>"];
	[s appendString:@"    <feature var='http://jabber.org/protocol/disco#info'/>"];
	[s appendString:@"    <feature var='http://jabber.org/protocol/disco#items'/>"];
	[s appendString:@"    <feature var='http://jabber.org/protocol/muc'/>"];
	[s appendString:@"    <x xmlns='jabber:x:data' type='result'>"];
	[s appendString:@"      <field var='FORM_TYPE' type='hidden'>"];
	[s appendString:@"        <value>urn:xmpp:dataforms:softwareinfo</value>"];
	[s appendString:@"      </field>"];
	[s appendString:@"      <field var='ip_version'>"];
	[s appendString:@"        <value>ipv4</value>"];
	[s appendString:@"        <value>ipv6</value>"];
	[s appendString:@"      </field>"];
	[s appendString:@"      <field var='os'>"];
	[s appendString:@"        <value>Mac</value>"];
	[s appendString:@"      </field>"];
	[s appendString:@"      <field var='os_version'>"];
	[s appendString:@"        <value>10.5.1</value>"];
	[s appendString:@"      </field>"];
	[s appendString:@"      <field var='software'>"];
	[s appendString:@"        <value>Psi</value>"];
	[s appendString:@"      </field>"];
	[s appendString:@"      <field var='software_version'>"];
	[s appendString:@"        <value>0.11</value>"];
	[s appendString:@"      </field>"];
	[s appendString:@"    </x>"];
	[s appendString:@"  </query>"];
	[s appendString:@"</iq>"];
	
	NSXMLDocument *doc = [[[NSXMLDocument alloc] initWithXMLString:s options:0 error:nil] autorelease];
	
	NSXMLElement *iq = [doc rootElement];
//	NSLog(@"iq:\n%@", [iq XMLStringWithOptions:(NSXMLNodeCompactEmptyElement | NSXMLNodePrettyPrint)]);
	
	NSLog(@"test2 result   : %@", [self hashCapabilities:iq]);
	NSLog(@"expected result: q07IKJEyjvHSyhy//CH0CxmKi8w=");
	
	NSLog(@"============================================================");
}

- (void)test3
{
	NSLog(@"============================================================");
	
	NSMutableString *s = [NSMutableString string];
	[s appendString:@"<iq from='benvolio@capulet.lit/230193' type='result'>"];
	[s appendString:@"  <query node='http://pidgin.im/#WsE3KKs1gYLeYKAn5zQHkTkRnUA='"];
	[s appendString:@"        xmlns='http://jabber.org/protocol/disco#info'>"];
	[s appendString:@"    <identity category='client' name='Pidgin' type='pc'/>"];
	[s appendString:@"    <feature var='jabber:iq:last'/>"];
	[s appendString:@"    <feature var='jabber:iq:oob'/>"];
	[s appendString:@"    <feature var='urn:xmpp:time'/>"];
	[s appendString:@"    <feature var='jabber:iq:version'/>"];
	[s appendString:@"    <feature var='jabber:x:conference'/>"];
	[s appendString:@"    <feature var='http://jabber.org/protocol/bytestreams'/>"];
	[s appendString:@"    <feature var='http://jabber.org/protocol/caps'/>"];
	[s appendString:@"    <feature var='http://jabber.org/protocol/chatstates'/>"];
	[s appendString:@"    <feature var='http://jabber.org/protocol/disco#info'/>"];
	[s appendString:@"    <feature var='http://jabber.org/protocol/disco#items'/>"];
	[s appendString:@"    <feature var='http://jabber.org/protocol/muc'/>"];
	[s appendString:@"    <feature var='http://jabber.org/protocol/muc#user'/>"];
	[s appendString:@"    <feature var='http://jabber.org/protocol/si'/>"];
	[s appendString:@"    <feature var='http://jabber.org/protocol/si/profile/file-transfer'/>"];
	[s appendString:@"    <feature var='http://jabber.org/protocol/xhtml-im'/>"];
	[s appendString:@"    <feature var='urn:xmpp:ping'/>"];
	[s appendString:@"    <feature var='urn:xmpp:bob'/>"];
	[s appendString:@"    <feature var='urn:xmpp:jingle:1'/>"];
	[s appendString:@"    <feature var='urn:xmpp:jingle:transports:raw-udp:1'/>"];
	[s appendString:@"    <feature var='http://www.google.com/xmpp/protocol/session'/>"];
	[s appendString:@"    <feature var='http://www.google.com/xmpp/protocol/voice/v1'/>"];
	[s appendString:@"    <feature var='http://www.google.com/xmpp/protocol/video/v1'/>"];
	[s appendString:@"    <feature var='http://www.google.com/xmpp/protocol/camera/v1'/>"];
	[s appendString:@"    <feature var='urn:xmpp:jingle:apps:rtp:audio'/>"];
	[s appendString:@"    <feature var='urn:xmpp:jingle:apps:rtp:video'/>"];
	[s appendString:@"    <feature var='urn:xmpp:jingle:transports:ice-udp:1'/>"];
	[s appendString:@"    <feature var='urn:xmpp:avatar:metadata'/>"];
	[s appendString:@"    <feature var='urn:xmpp:avatar:data'/>"];
	[s appendString:@"    <feature var='urn:xmpp:avatar:metadata+notify'/>"];
	[s appendString:@"    <feature var='http://jabber.org/protocol/mood'/>"];
	[s appendString:@"    <feature var='http://jabber.org/protocol/mood+notify'/>"];
	[s appendString:@"    <feature var='http://jabber.org/protocol/tune'/>"];
	[s appendString:@"    <feature var='http://jabber.org/protocol/tune+notify'/>"];
	[s appendString:@"    <feature var='http://jabber.org/protocol/nick'/>"];
	[s appendString:@"    <feature var='http://jabber.org/protocol/nick+notify'/>"];
	[s appendString:@"    <feature var='http://jabber.org/protocol/ibb'/>"];
	[s appendString:@"  </query>"];
	[s appendString:@"</iq>"];
	
	NSXMLDocument *doc = [[[NSXMLDocument alloc] initWithXMLString:s options:0 error:nil] autorelease];
	
	NSXMLElement *iq = [doc rootElement];
//	NSLog(@"iq:\n%@", [iq XMLStringWithOptions:(NSXMLNodeCompactEmptyElement | NSXMLNodePrettyPrint)]);
	
	NSLog(@"test3 result   : %@", [self hashCapabilities:iq]);
	NSLog(@"expected result: WsE3KKs1gYLeYKAn5zQHkTkRnUA=");
	
	NSLog(@"============================================================");
}

#if TARGET_OS_IPHONE

- (void)applicationDidFinishLaunching:(UIApplication *)application
{
	// IPHONE TEST
	
	[self test1];
	[self test2];
	[self test3];
	
	[window addSubview:viewController.view];
	[window makeKeyAndVisible];
}

#else

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// MAC TEST
	
	[self test1];
	[self test2];
	[self test3];
}

#endif
@end
