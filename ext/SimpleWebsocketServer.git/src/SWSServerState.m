//
//  ServerState.m
//  ReverseStreamer
//
//  Created by Yukishita Yohsuke on 2014/06/08.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//
#include <objc/message.h>

#import <MDWUtils/NSString+Crypto.h>

#import "SWSServerState.h"
#import "SWSServerSettingMaster.h"
#import "SWSAbstractFactory.h"
#import "SWSConnectionHandler.h"

typedef NS_ENUM(NSUInteger, ServerMachineState) {
    SERVER_STATE_INIT = 0,
    SERVER_STATE_RUNNING = 1,
};

@interface SWSServerState() {
    ServerMachineState _state;
    SWSServerSetting *_current_setting;
    NSMutableSet *_connection_delegates;
    SWSServerSettingMaster *_setting_master;
}

@end

@implementation SWSServerState

+ (instancetype)sharedMachine
{
    static SWSServerState *__instance;
    static dispatch_once_t __once_token;

    dispatch_once(&__once_token, ^{
        SWSServerState *obj = [[[self class] alloc] init];

        [obj _setup];

        __instance = obj;
    });

    return __instance;
}

- (SWSServerSetting *)current_setting
{
    SWSServerSetting *result;

    @synchronized(self) {
        result = _current_setting;
    }

    return result;
}

- (BOOL)_setup
{
    _connection_delegates = [NSMutableSet set];
    _state = SERVER_STATE_INIT;
    _setting_master = [SWSServerSettingMaster sharedMaster];
    _current_setting = [_setting_master loadOrDefault]; // DEBUG
    _server_port = 0;

    return YES;
}

#pragma mark -
#pragma mark Connections

#define __delegate_selector(delegate, selector, ...) { \
    if ([delegate respondsToSelector:(selector)]) { \
        objc_msgSend(delegate, selector, ##__VA_ARGS__); \
    } \
}

#define __distribute_children_selector(delegate_set, selector, ...) { \
    @synchronized(self) { \
        NSSet *___set = [NSSet setWithSet:(delegate_set)]; \
        for (id<SWSServerToConnectionDelegate> listener in ___set) { \
            __delegate_selector(listener, (selector), ##__VA_ARGS__); \
        } \
    } \
}

- (NSUInteger)numConnections
{
    return _connection_delegates.count;
}

- (void)attachConnectionDelegate:(id<SWSServerToConnectionDelegate>)delegate
{
    ASSERT(delegate != nil, return);

    @synchronized(self) {
        [_connection_delegates addObject:delegate];
    }
}

- (void)detachChildDelegate:(id<SWSServerToConnectionDelegate>)delegate
{
    ASSERT(delegate != nil, return);

    @synchronized(self) {
        [_connection_delegates removeObject:delegate];
    }
}

- (void)iterateHandlers:(void (^)(SWSConnectionHandler *))block
{
    @synchronized(self) {
        NSSet *___set = [NSSet setWithSet:(_connection_delegates)];
        for (id<SWSServerToConnectionDelegate> delegate in ___set) {
            block(delegate.handler);
        }
    }
}

- (BOOL)authorizePassword:(NSString *)password_digest withSeed:(NSString *)seed
{
    DBG(@"digest: %@", password_digest);

    NSString *me = [NSPRINTF(@"%@%@%@", _current_setting.password_sha1, [SWSControlMessage password_bridge_str], seed) sha1String];

    return [me isEqualToString:password_digest];
}

- (void)disconnectAll
{
    __distribute_children_selector(_connection_delegates, @selector(die));
}

#pragma mark -
#pragma mark Settings
- (BOOL)changeSetting:(SWSServerSetting *)setting
{
    EXPECT(setting != nil, return NO);

    @synchronized(self) {
        _current_setting = setting;
    }

    [_setting_master save:_current_setting];

    return YES;
}

#pragma mark -
#pragma mark Setting change: Server

- (void)changePassword:(NSString *)plain_text
{
    NSString *prev_hash = _current_setting.password_sha1;

    SWSServerSetting *new_setting = [_setting_master changePasswordByPlain:plain_text of:_current_setting];

    if (![prev_hash isEqualToString:new_setting.password_sha1]) {
        [self changeSetting:new_setting];
        [self disconnectAll];
    }
}

#pragma mark -
#pragma mark Start/Stop
- (void)periodicTask
{
    if (_connection_delegates.count > 0) {
        __distribute_children_selector(_connection_delegates, @selector(doPeriodicTask));
    }
}

@end
