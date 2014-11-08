//
//  SWSAbstractFactory.m
//  ReverseStreamer
//
//  Created by Yukishita Yohsuke on H26/06/12.
//  Copyright (c) 平成26年 monadworks. All rights reserved.
//

#include <objc/message.h>

#import "SWSAbstractFactory.h"
#import "SWSPerformanceStatistics.h"
#import "SWSConnectionHandler.h"
@implementation SWSAbstractFactory

+ (instancetype)sharedFactory
{
    static SWSAbstractFactory *__instance;
    static dispatch_once_t __once_token;
    dispatch_once(&__once_token, ^{
        __instance = [[SWSAbstractFactory alloc] init];
        [__instance _setup];
    });
    return __instance;
}

- (void)_setup
{
    _message_classes = [NSMutableArray array];
    
    self.http_connection_class = [SWSHTTPConnection class];

    self.generateConnectionHandler = ^(SWSConnectionState *connection) {
        return [SWSConnectionHandler createWithConnection:connection];
    };
}

- (void)registerMessageClass:(Class)message_class
{
    [_message_classes addObject:message_class];
}

- (BOOL)forwardMessage:(SWSMessage *)msg forDelegate:(id<SWSOnReadMessageDelegate>)delegate
{
    NSUInteger category = msg.category;
    
    for (Class class in _message_classes) {
        if ((NSUInteger)[class performSelector:@selector(_category)] == category) {
            objc_msgSend(class, @selector(message:parseForDelegate:), msg, delegate);
            return YES;
        }
    }
    
    ERROR(@"Unknown category 0x%04x", (unsigned)msg.category);

    return NO;
}

- (BOOL)forwardData:(NSData *)data forDelegate:(id<SWSOnReadMessageDelegate>)delegate
{
    SWSMessage *msg = nil;
    
    ASSERT(msg = [SWSMessage createFromData:data], return NO);
    
    return [self forwardMessage:msg forDelegate:delegate];
}

@end
