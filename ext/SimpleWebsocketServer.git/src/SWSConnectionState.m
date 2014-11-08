//
//  ConnectionState.m
//  ReverseStreamer
//
//  Created by Yukishita Yohsuke on 2014/06/08.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import "SWSConnectionState.h"
#import "SWSAbstractFactory.h"
#import "SWSConnectionHandler.h"
#import "NSString+Randomize.h"

#define AUTHORIZATION_MAX_FAIL_COUNT (5)

#define CONNECTION_TIMEOUT_SEC (5.0f)
#define CONNECTION_VIDEO_PROCESS_TIMEOUT_SEC (1.0f)
#define CONNECTION_AUDIO_BUFFER_UNIT (1024 * 2)
#define CONNECTION_AUDIO_MAXIMUM_BUFFER_LENGTH (16 * CONNECTION_AUDIO_BUFFER_UNIT)
#define CONNECTION_AUDIO_ALLOWD_BUFFER_NUM (4)

typedef NS_ENUM(NSUInteger, ServerConnectionState) {
    CONNECTION_STATE_INIT = 0,
    CONNECTION_STATE_WAIT_SETTING = 1,
    CONNECTION_STATE_WAIT_START = 2,
    CONNECTION_STATE_STREAMING = 3,
};

@interface SWSConnectionState() {
    ServerConnectionState _state;
    SWSAbstractFactory *_factory;
    SWSServerState *_server_state;
    SWSServerSettingMaster *_setting_master;
    SWSPerformanceStatistics *_performance_statistics;
    SWSWebsocket *_socket;

    BOOL _enable_audio;
    BOOL _authorized;

    // timestamps
    uint64_t _open_mach_time;
    uint64_t _init_mach_time;
    uint64_t _last_receive_mach_time;

    // client report
    uint32_t _report_receive_count;

    // server
    BOOL _cooldown_mode;
    int _authorize_fail_count;

    NSString *_password_seed;
    NSString *_host_str;
}

@end

static mach_timebase_info_data_t __mach_timebase = {};
static uint64_t __ticks_for_second = 0;

static inline double __calc_mach_offset_seconds(uint64_t from, uint64_t to)
{
    uint64_t const nsec = ((to - from) * (double)__mach_timebase.numer) / (double)__mach_timebase.denom;

    return nsec / 1e9;
}

@implementation SWSConnectionState

+ (instancetype)createWithSocket:(SWSWebsocket *)socket
{
    SWSConnectionState *obj = [[[self class] alloc] init];

    ASSERT([obj _setupWithSocket:socket], return nil);

    return obj;
}

- (void)_onReceive
{
    _last_receive_mach_time = mach_absolute_time();
}

- (BOOL)_setupWithSocket:(SWSWebsocket *)socket
{
    _socket = socket;
    _factory = [SWSAbstractFactory sharedFactory];
    _setting_master = [SWSServerSettingMaster sharedMaster];
    _server_state = [SWSServerState sharedMachine];
    [_server_state attachConnectionDelegate:self];
    _host_str = [socket hostName];

    _state = CONNECTION_STATE_INIT;

    static dispatch_once_t __once_token;
    dispatch_once(&__once_token, ^{
        mach_timebase_info(&__mach_timebase);
        __ticks_for_second = ((double)__mach_timebase.denom / (double)__mach_timebase.numer) * 1e9;
    });

    [self _onReceive];

    if (_server_state.current_setting.password_sha1.length > 0) {
        _authorized = NO;
    } else {
        _authorized = YES;
    }

    _performance_statistics = [SWSPerformanceStatistics create];

    _open_mach_time = mach_absolute_time();
    
    return YES;
}

- (void)detachDelegateFromServerState
{
    _state = CONNECTION_STATE_INIT;
    _socket = nil;
    @synchronized(self) {
        [_server_state detachChildDelegate:self];
    }
}

- (void)_finish
{
    @synchronized(self) {
        _enable_audio = NO;

        [_socket disconnectNow];
        [self detachDelegateFromServerState];

        [_handler connectionOnFinished];
    }
}

- (void)dealloc
{
    [self _finish];
}

- (void)sendIt:(SWSMessage *)message
{
    [_performance_statistics increaseOutputNetworkBytes:message.data.length];
    [_socket sendData:message.data];
}

- (void)sendMultiPart:(SWSMessage *)message withPayload:(NSData *)payload
{
    [_performance_statistics increaseOutputNetworkBytes:(message.data.length + payload.length)];
    [_socket sendBigOne:message.data withPayload:payload];
}

- (void)readIt:(SWSMessage *)message
{
    EXPECT(_state == CONNECTION_STATE_STREAMING, return);

    [_factory forwardMessage:message forDelegate:self];
}

- (void)setSocket:(SWSWebsocket *)socket
{
    _socket = socket;
}

- (void)parseAndReadIt:(NSData *)data
{
    [_performance_statistics increaseInputNetworkBytes:data.length];

    SWSMessage *message = [SWSMessage createFromData:data];
    EXPECT(message != nil, return);

    if ([SWSControlMessage message:message parseForDelegate:self] == YES) {
        [self _onReceive];
        return;
    } else if (_authorized == NO) {
        WARN("illegal access");
        [self sendIt:[SWSControlMessage createReset]];
        [self _finish];
    } else if ([_factory forwardData:data forDelegate:_handler] == YES) {
        [self _onReceive];
        return;
    } else {
        WARN("parse error");
        [self sendIt:[SWSControlMessage createReset]];
        [self _finish];
    }
}

#pragma mark -
#pragma mark Control Packet Delegate

- (BOOL)onHello
{
    switch (_state) {
        case CONNECTION_STATE_INIT:

            if (!_authorized) {
                _password_seed = [NSString stringWithRandomAlphanum:32];
                [self sendIt:[SWSControlMessage createPasswordRequired:_password_seed]];
                return YES;
            } else {
                _state = CONNECTION_STATE_WAIT_SETTING;
                _password_seed = nil;
                [_handler connectionOnAuthorized];
            }
            break;
        default:
            // keep state
            break;
    }

    [self sendIt:[SWSControlMessage createHello]];

    _init_mach_time = mach_absolute_time();

    return YES;
}

- (BOOL)onPassword:(NSString *)password
{
    EXPECT(_state == CONNECTION_STATE_INIT && !_authorized, return NO);

    if ([_server_state authorizePassword:password withSeed:_password_seed]) {
        _authorized = YES;
    } else {
        DBG("password authorization failed!");
        if (++_authorize_fail_count > AUTHORIZATION_MAX_FAIL_COUNT) {
            DBG("reached password trial limit");
            return NO;
        }
    }

    return YES;
}

- (BOOL)onWaitingInput
{
    // just update health check timer to extend timeout
    return YES;
}

#pragma mark -
#pragma mark Messages From Server State Machine

- (void)doPeriodicTask
{
    if (__calc_mach_offset_seconds(_last_receive_mach_time, mach_absolute_time()) > CONNECTION_TIMEOUT_SEC) {
        INFO("client timeout");
        [self _finish];
    } else if (_state == CONNECTION_STATE_INIT && !_authorized) {
        [self sendIt:[SWSControlMessage createWaitingInput]];
    }
}

- (void)die
{
    [self _finish];
}

@end
