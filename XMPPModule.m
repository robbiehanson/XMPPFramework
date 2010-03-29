#import "XMPPModule.h"
#import "XMPPStream.h"
#import "MulticastDelegate.h"


@implementation XMPPModule

@synthesize xmppStream;

- (id)initWithStream:(XMPPStream *)aXmppStream
{
	if ((self = [super init]))
	{
		xmppStream = [aXmppStream retain];
		[xmppStream addDelegate:self];
		
		[xmppStream registerModule:self];
		
		multicastDelegate = [[ModuleMulticastDelegate alloc] initWithStream:xmppStream];
	}
	return self;
}

- (void)dealloc
{
	[xmppStream unregisterModule:self];
	
	[xmppStream removeDelegate:self];
	[xmppStream release];
	
	[multicastDelegate release];
	
	[super dealloc];
}

- (void)addDelegate:(id)delegate
{
	[multicastDelegate addDelegate:delegate];
}

- (void)removeDelegate:(id)delegate
{
	[multicastDelegate removeDelegate:delegate];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface MulticastDelegate (ModuleMulticastDelgate)

// Quiet the compiler.
// This method is not declared in 10.5, and on the iPhone.
- (id)forwardingTargetForSelector:(SEL)aSelector;

@end

@implementation ModuleMulticastDelegate

- (id)initWithStream:(XMPPStream *)aXmppStream
{
	if ((self = [super init]))
	{
		xmppStream = [aXmppStream retain];
	}
	return self;
}

- (void)dealloc
{
	[xmppStream release];
	[super dealloc];
}

- (id)forwardingTargetForSelector:(SEL)aSelector
{
	// If there is a single target that responds to this selector, we can take advantage of the forwarding fast path.
	// That is, there is one and only one target that responds to this selector.
	// If there is more than one, we need to use the usual forwarding path.
	
	id dft = [super forwardingTargetForSelector:aSelector];
	
	if (dft)
	{
		id mft = [[xmppStream registeredModules] forwardingTargetForSelector:aSelector];
		
		if (mft)
			return nil;
		else
			return dft;
	}
	
	return [[xmppStream registeredModules] forwardingTargetForSelector:aSelector];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
	// We just need to get the proper method signature.
	// If any of the delegates implement the selector, then we can get the proper signature.
	// It doesn't matter which delegate we get the signature from (because they're all the same).
	// We just need to get it from one of them.
	// 
	// If the method signature isn't found, the signature for "-(void)doNothing" is returned.
	
	NSMethodSignature *dms = [super methodSignatureForSelector:aSelector];
	
	if ([dms numberOfArguments] > 0)
	{
		return dms;
	}
	
	return [[xmppStream registeredModules] methodSignatureForSelector:aSelector];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
	// Forward the invocation to all our delegates.
	// And then forward the invocation to all registered modules that respond to the selector.
	
	[super forwardInvocation:anInvocation];
	[[xmppStream registeredModules] forwardInvocation:anInvocation];
}

@end