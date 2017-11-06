#import "XMPPMessageCoreDataStorage+XEP_0245.h"

@implementation XMPPMessageCoreDataStorageObject (XEP_0245)

- (NSString *)meCommandText
{
    NSRange meCommandPrefixRange = [self meCommandPrefixRange];
    return meCommandPrefixRange.location != NSNotFound ? [self.body stringByReplacingCharactersInRange:meCommandPrefixRange withString:@""] : nil;
}

- (XMPPJID *)meCommandSubjectJID
{
    if ([self meCommandPrefixRange].location == NSNotFound) {
        return nil;
    }
    
    if (self.fromJID) {
        return self.fromJID;
    } else {
        NSAssert(self.direction == XMPPMessageDirectionOutgoing, @"Only outgoing messages without from JID are supported here");
        return [self streamJID];
    }
}

- (NSRange)meCommandPrefixRange
{
    return [self.body rangeOfString:@"/me " options:NSAnchoredSearch];
}

@end
