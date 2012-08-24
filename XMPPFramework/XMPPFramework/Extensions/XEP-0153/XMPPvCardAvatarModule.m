//
//  XMPPvCardAvatarModule.h
//  XEP-0153 vCard-Based Avatars
//
//  Created by Eric Chamberlain on 3/9/11.
//  Copyright 2011 RF.com. All rights reserved.


// TODO: publish after upload vCard
/*
 * XEP-0153 Section 4.2 rule 1
 *
 * However, a client MUST advertise an image if it has just uploaded the vCard with a new avatar 
 * image. In this case, the client MAY choose not to redownload the vCard to verify its contents.
 */

#import "XMPPvCardAvatarModule.h"

#import "NSData+XMPP.h"
#import "NSXMLElement+XMPP.h"
#import "XMPPLogging.h"
#import "XMPPPresence.h"
#import "XMPPStream.h"
#import "XMPPvCardTempModule.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

// Log levels: off, error, warn, info, verbose
// Log flags: trace
#if DEBUG
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN; // | XMPP_LOG_FLAG_TRACE;
#else
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

NSString *const kXMPPvCardAvatarElement = @"x";
NSString *const kXMPPvCardAvatarNS = @"vcard-temp:x:update";
NSString *const kXMPPvCardAvatarPhotoElement = @"photo";


@implementation XMPPvCardAvatarModule

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Init/dealloc
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (id)init
{
	// This will cause a crash - it's designed to.
	// Only the init methods listed in XMPPvCardAvatarModule.h are supported.
	
	return [self initWithvCardTempModule:nil dispatchQueue:NULL];
}

- (id)initWithDispatchQueue:(dispatch_queue_t)queue
{
	// This will cause a crash - it's designed to.
	// Only the init methods listed in XMPPvCardAvatarModule.h are supported.
	
	return [self initWithvCardTempModule:nil dispatchQueue:NULL];
}

- (id)initWithvCardTempModule:(XMPPvCardTempModule *)xmppvCardTempModule
{
  return [self initWithvCardTempModule:xmppvCardTempModule dispatchQueue:NULL];
}

- (id)initWithvCardTempModule:(XMPPvCardTempModule *)xmppvCardTempModule dispatchQueue:(dispatch_queue_t)queue
{
	NSParameterAssert(xmppvCardTempModule != nil);

	if ((self = [super initWithDispatchQueue:queue])) {
		_xmppvCardTempModule = xmppvCardTempModule;

		// we don't need to call the storage configureWithParent:queue: method,
		// because the vCardTempModule already did that.
		_moduleStorage = (id <XMPPvCardAvatarStorage>)xmppvCardTempModule.moduleStorage;

		[_xmppvCardTempModule addDelegate:self delegateQueue:moduleQueue];
	}
	return self;
}


- (void)dealloc {
	[_xmppvCardTempModule removeDelegate:self];

	_moduleStorage = nil;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Public
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSData *)photoDataForJID:(XMPPJID *)jid 
{
	// This is a public method, so it may be invoked on any thread/queue.
	// 
	// The vCardTempModule is thread safe.
	// The moduleStorage should be thread safe. (User may be using custom module storage class).
	// The multicastDelegate is NOT thread safe.
	
	__block NSData *photoData;
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		photoData = [_moduleStorage photoDataForJID:jid xmppStream:xmppStream];
		
		if (photoData == nil) 
		{
			[_xmppvCardTempModule fetchvCardTempForJID:jid useCache:YES];
		}
		else
		{
		#if TARGET_OS_IPHONE
			UIImage *photo = [UIImage imageWithData:photoData];
		#else
			NSImage *photo = [[NSImage alloc] initWithData:photoData];
		#endif
			
			[multicastDelegate xmppvCardAvatarModule:self 
			                         didReceivePhoto:photo 
			                                  forJID:jid];
		}
		
	}};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_sync(moduleQueue, block);
	
	return photoData;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStreamDelegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppStreamWillConnect:(XMPPStream *)sender {
	XMPPLogTrace();
	/* 
	 * XEP-0153 Section 4.2 rule 1
	 *
	 * A client MUST NOT advertise an avatar image without first downloading the current vCard. 
	 * Once it has done this, it MAY advertise an image. 
	 */
	[_moduleStorage clearvCardTempForJID:[sender myJID] xmppStream:xmppStream];
}


- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender {
	XMPPLogTrace();
	[_xmppvCardTempModule fetchvCardTempForJID:[sender myJID] useCache:NO];
}


- (XMPPPresence *)xmppStream:(XMPPStream *)sender willSendPresence:(XMPPPresence *)presence {
	XMPPLogTrace();

	// add our photo info to the presence stanza
	NSXMLElement *photoElement = nil;
	NSXMLElement *xElement = [NSXMLElement elementWithName:kXMPPvCardAvatarElement xmlns:kXMPPvCardAvatarNS];

	NSString *photoHash = [_moduleStorage photoHashForJID:[sender myJID] xmppStream:xmppStream];

	if (photoHash != nil) {
		photoElement = [NSXMLElement elementWithName:kXMPPvCardAvatarPhotoElement stringValue:photoHash];
	} else {
		photoElement = [NSXMLElement elementWithName:kXMPPvCardAvatarPhotoElement];
	}

	[xElement addChild:photoElement];
	[presence addChild:xElement];

	// Question: If photoElement is nil, should we be adding xElement?
	
	return presence;
}


- (void)xmppStream:(XMPPStream *)sender didReceivePresence:(XMPPPresence *)presence  {
	XMPPLogTrace();

	NSXMLElement *xElement = [presence elementForName:kXMPPvCardAvatarElement xmlns:kXMPPvCardAvatarNS];

	if (xElement == nil) {
		return;
	}

	NSString *photoHash = [[xElement elementForName:kXMPPvCardAvatarPhotoElement] stringValue];

	if (photoHash == nil || [photoHash isEqualToString:@""]) {
		return;
	}

	XMPPJID *jid = [presence from];

	// check the hash
	if (![photoHash isEqualToString:[_moduleStorage photoHashForJID:jid xmppStream:xmppStream]]) {
		[_xmppvCardTempModule fetchvCardTempForJID:jid useCache:NO];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPvCardTempModuleDelegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppvCardTempModule:(XMPPvCardTempModule *)vCardTempModule 
        didReceivevCardTemp:(XMPPvCardTemp *)vCardTemp 
                     forJID:(XMPPJID *)jid
{
	XMPPLogTrace();
	
	if (vCardTemp.photo != nil)
	{
	#if TARGET_OS_IPHONE
		UIImage *photo = [UIImage imageWithData:vCardTemp.photo];
	#else
		NSImage *photo = [[NSImage alloc] initWithData:vCardTemp.photo];
	#endif
		
		if (photo != nil)
		{
			[multicastDelegate xmppvCardAvatarModule:self
			                         didReceivePhoto:photo
			                                  forJID:jid];
		}
	}
	
	/*
	 * XEP-0153 4.1.3
	 * If the client subsequently obtains an avatar image (e.g., by updating or retrieving the vCard), 
	 * it SHOULD then publish a new <presence/> stanza with character data in the <photo/> element.
	 */
	if ([[xmppStream myJID] isEqualToJID:jid options:XMPPJIDCompareBare])
	{
		XMPPPresence *presence = xmppStream.myPresence;
		if(presence) {
			[xmppStream sendElement:presence];
		}
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Getter/setter
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@synthesize xmppvCardTempModule = _xmppvCardTempModule;


@end
