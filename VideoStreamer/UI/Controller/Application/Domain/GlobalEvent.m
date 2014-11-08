//
//  GlobalStateMachine.m
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/03/05.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//
#include <objc/message.h>
#include <libkern/OSAtomic.h>
#import <MDWUtils/UIDevice+IPAddress.h>
#import <SimpleWebsocketServer/SWSServerState.h>
#import "GlobalEvent.h"
#import "ConnectionHandler.h"

typedef NS_ENUM(NSUInteger, ServerMachineState) {
    SERVER_STATE_INIT = 0,
    SERVER_STATE_RUNNING = 1,
};

@interface GlobalEvent() {
    ServerMachineState _state;
    StreamingSetting *_current_streaming_setting;
    SettingMaster *_setting_master;
    SWSServerState *_server_state;
    uint _power_saving_mode_count;
    BOOL _power_saving_mode;
    uint _current_num_streaming_connections;
    BOOL _need_dim_screen;
}

@end

#define USE_SPINLOCK

#ifdef USE_SPINLOCK
/*
static volatile int __lock = 0;

#define SPIN_LOCK_LOCK(x) while (OSAtomicCompareAndSwapInt(0, 1, x) == false) { }
#define SPIN_LOCK_UNLOCK(x) *x = 0;

#define SETTING_LOCK SPIN_LOCK_LOCK(&__lock)
#define SETTING_UNLOCK SPIN_LOCK_UNLOCK(&__lock)
 */
static volatile OSSpinLock __lock = OS_SPINLOCK_INIT;
#define SETTING_LOCK OSSpinLockLock(&__lock)
#define SETTING_UNLOCK OSSpinLockUnlock(&__lock)
#else
#define SETTING_LOCK @synchronized(_server_state) {
#define SETTING_UNLOCK }
#endif

#define POWER_SAVING_MODE_WAIT_COUNT_THRESHOLD (3)

@implementation GlobalEvent

+ (instancetype)sharedMachine
{
    static GlobalEvent *__instance;
    static dispatch_once_t __once_token;

    dispatch_once(&__once_token, ^{
        GlobalEvent *obj = [[[self class] alloc] init];

        [obj _setup];

        __instance = obj;
    });

    return __instance;
}

- (BOOL)_setup
{
    _state = SERVER_STATE_INIT;
    _setting_master = [SettingMaster sharedMaster];
    _current_streaming_setting = [_setting_master loadOrDefault];
    _current_num_streaming_connections = 0;
    _upnp_enabled = 0;
    _server_port = 0;
    _server_state = [SWSServerState sharedMachine];
    _need_dim_screen = NO;

    return YES;
}

- (void)setDelegate:(id<GlobalEventDelegate>)delegate
{
    _delegate = delegate;

    if (_need_dim_screen) {
        _need_dim_screen = NO;
        [_delegate dimScreen];
    }

    [_delegate setPlaybackMode:_current_streaming_setting.playback_enabled];
}

- (void)setPlaybackMode:(BOOL)enable
{
    [self _changeStreamingSetting:[_setting_master changePlaybackMode:enable of:_current_streaming_setting]];

    [_delegate setPlaybackMode:_current_streaming_setting.playback_enabled];

    if (enable) {
        [_delegate wakeUpVideo];
    }
}

- (BOOL)set60FpsMode:(BOOL)enable
{
    if (enable == YES && ![_delegate canSet60fps]) return NO;

    [self _changeStreamingSetting:[_setting_master changeEnable60fps:enable of:_current_streaming_setting]];

    return [_delegate set60fpsMode:_current_streaming_setting.enable_60fps];
}

- (void)changeFramerateLimit:(int)limit
{
    [self _changeStreamingSetting:[_setting_master changeFramerateLimit:limit of:_current_streaming_setting]];

    return [_delegate changeCameraFPS:_current_streaming_setting.framerate_limit];
}

- (BOOL)support60Fps
{
    return [_delegate canSet60fps];
}

- (BOOL)supportsLightControl
{
    return [_delegate supportsLightControl];
}

- (LightControlStatus)currentLightStatus
{
    return [_delegate currentLightStatus];
}

- (FocusControlStatus)currentFocusStatus
{
    return [_delegate currentFocusStatus];
}

- (StreamingSetting *)current_streaming_setting
{
    StreamingSetting *result;

    SETTING_LOCK;
    result = _current_streaming_setting;
    SETTING_UNLOCK;

    return result;
}

- (BOOL)prepareCustomURLCommand:(NSString *)command
{
    if (command == nil) return YES;

    BOOL ret = NO;

    if ([command isEqualToString:@"dark"]) {
        [self setPlaybackMode:NO];

        if (_delegate != nil && [_delegate respondsToSelector:@selector(dimScreen)]) {
            [_delegate dimScreen];
        } else {
            _need_dim_screen = YES;
        }

        ret = YES;
    }

    return ret;
}


#pragma mark -
#pragma mark Networking

- (void)changeURLType:(BOOL)use_mdns
{
    [self _changeStreamingSetting:[_setting_master changeURLDisplayMDNS:use_mdns of:_current_streaming_setting] withClientNotification:NO];

    [_delegate changeMdnsMode:use_mdns];
}

- (NSString *)generateCurrentURL
{
    uint16_t port = self.server_port;
    NSString *ip_address = [UIDevice getLocalIP];
    NSString *host_name = nil;
    NSString *url = nil;

    if (self.current_streaming_setting.url_display_mdns) {
        host_name = [NSPRINTF(@"%@.", [[NSProcessInfo processInfo] hostName]) lowercaseString];

        if (![[host_name substringFromIndex:(host_name.length - 7)] isEqualToString:@".local."]) {
            if ([[host_name substringFromIndex:(host_name.length - 1)] isEqualToString:@"."]) {
                host_name = NSPRINTF(@"%@local.", host_name);
            } else {
                host_name = NSPRINTF(@"%@.local.", host_name);
            }
        }
    } else {
        host_name = ip_address;
    }

    if (ip_address && port != 0) {
        if (port == 80) {
            url = NSPRINTF(@"http://%@", host_name);
        } else {
            url = NSPRINTF(@"http://%@:%d", host_name, port);
        }
    }

    return url;
}

#pragma mark -
#pragma mark Message to global state: Streaming

- (void)_countStreamingConnections
{
    __block NSUInteger count = 0;

    [_server_state iterateHandlers:^(SWSConnectionHandler *handler) {
        if ([((ConnectionHandler *)handler) areYouStreaming] == YES) {
            ++count;
        }
    }];

    _current_num_streaming_connections = count;
}

- (NSUInteger)currentStreamingConnections
{
    return _current_num_streaming_connections;
}

- (void)prepareForIncomingConnection
{
    _power_saving_mode = NO;
    _power_saving_mode_count = 0;

    [_delegate wakeUpVideo];
    [_delegate wakeUpAudio];
}

- (void)connectionWillBeginStreaming
{
    [self _countStreamingConnections];

    [_delegate forceIFrame];
}

- (void)connectionIsSuccessfull
{
#ifdef DEBUG
    DBG(@"successfull connection: %d",
        _current_streaming_setting.successfull_connection_count + 1);
#endif

    [self _changeStreamingSetting:[_setting_master increaseSuccessfullConnectionCount:_current_streaming_setting] withClientNotification:NO];
}

- (void)requestIFrame
{
    [_delegate forceIFrame];
}

- (void)gotNewEncodedAudio:(NSData *)audio_buffer withStartSample:(int16_t)start_sample withStartIndex:(int16_t)start_index withTimestamp:(struct timeval)timestamp
{
    if (_state != SERVER_STATE_RUNNING) {
        DBG(@"got audio but event machine is not running");
        return;
    }

    [_server_state iterateHandlers:^(SWSConnectionHandler *handler) {
        [((ConnectionHandler *)handler) newEncodedAudioArrived:audio_buffer withStartSample:start_sample withStartIndex:start_index withTimestamp:timestamp];
    }];
}

- (void)gotNewEncodedVideo:(TimestampedData *)video
{
    if (_state != SERVER_STATE_RUNNING) {
        DBG(@"got video but event machine is not running");
        return;
    }

    [_server_state iterateHandlers:^(SWSConnectionHandler *handler) {
        [((ConnectionHandler *)handler) newEncodedVideoArrived:video];
    }];
}

- (void)lightStatusChanged:(LightControlStatus)status
{
    [_server_state iterateHandlers:^(SWSConnectionHandler *handler) {
        [((ConnectionHandler *)handler) lightStatusChanged:status];
    }];
}

- (void)focusStatusChanged:(FocusControlStatus)status
{
    [_server_state iterateHandlers:^(SWSConnectionHandler *handler) {
        [((ConnectionHandler *)handler) focusStatusChanged:status];
    }];
}

- (NSArray *)gatherClientStatistics
{
    __block NSMutableArray *result = [NSMutableArray array];

    [_server_state iterateHandlers:^(SWSConnectionHandler *handler) {
        ConnectionInfo *stat = [((ConnectionHandler *)handler) reportStatistics];

        if (stat != nil) {
            [result addObject:stat];
        } else {
            DBG(@"nil statistics");
        }
    }];

    return result;
}

#pragma mark -
#pragma mark Setting change: Streaming

- (BOOL)_changeStreamingSetting:(StreamingSetting *)setting
{
    return [self _changeStreamingSetting:setting withClientNotification:YES];
}

- (BOOL)_changeStreamingSetting:(StreamingSetting *)setting withClientNotification:(BOOL)notify_client
{
    EXPECT(setting != nil, return NO);

    SETTING_LOCK;
    _current_streaming_setting = setting;
    SETTING_UNLOCK;

    if (notify_client) {
        [_server_state iterateHandlers:^(SWSConnectionHandler *handler) {
            [((ConnectionHandler *)handler) streamingSpecChanged:_current_streaming_setting];
        }];
    }

    // Always save
    [_setting_master save:_current_streaming_setting];

    return YES;
}

- (void)changeOrientation
{
    StreamingSetting *new_setting = [_setting_master changeOrientationOf:_current_streaming_setting];

    VSResizingROI *old_roi = _current_streaming_setting.roi;
    VSResizingROI *new_roi = [old_roi copy];
    CGSize old_size = _current_streaming_setting.capture_size;

    if (old_size.width > old_size.height) {
        new_roi.center = CGPointMake(old_roi.center.y, 1.0 - old_roi.center.x);
    } else {
        new_roi.center = CGPointMake(1.0 - old_roi.center.y, old_roi.center.x);
    }

    new_roi.degree = (old_roi.degree + 180) % 360;

    [self _changeStreamingSetting: [_setting_master changeROI:new_roi of:new_setting]];

    [_delegate roiChanged];
}

- (void)changeScreenSize:(CGSize)screen_size
{
    StreamingSetting *new_setting = [_setting_master changeScreenSize:screen_size of:_current_streaming_setting];

    [self _changeStreamingSetting:new_setting];

    if (_state == SERVER_STATE_INIT) {
        _state = SERVER_STATE_RUNNING;
    }
}

- (void)changeROI:(VSResizingROI *)roi
{
    StreamingSetting *new_setting = [_setting_master changeROI:roi of:_current_streaming_setting];

    [self _changeStreamingSetting:new_setting];

    [_delegate roiChanged];
}

- (void)changeImageQuality:(int)quality
{
    StreamingSetting *new_setting = [_setting_master changeQuality:quality of:_current_streaming_setting];

    [self _changeStreamingSetting:new_setting];
}

- (void)changeLevels:(uint8_t)resolution_level sound_buffering_level:(uint8_t)sound_buffering_level contrast_adjustment:(uint8_t)contrast_adjustment_level
{
    BOOL resolution_changed = NO;
    BOOL sound_buffering_changed = NO;
    BOOL contrast_adjustment_changed = NO;

    StreamingSetting *new_setting = _current_streaming_setting;

    // FIXME: shitty boiler plate
    if (resolution_level != _current_streaming_setting.resolution_level) {
        new_setting = [_setting_master changeResolutionLevel:resolution_level
                                                                       of:new_setting];
        resolution_changed = YES;
    }

    if (sound_buffering_level != _current_streaming_setting.sound_buffering_level) {
        new_setting = [_setting_master changeSoundBufferingLevel:sound_buffering_level of:new_setting];
        sound_buffering_changed = YES;
    }

    if (contrast_adjustment_level != _current_streaming_setting.contrast_adjustment_level) {
        new_setting = [_setting_master changeContrastAdjustmentLevel:contrast_adjustment_level of:new_setting];
        contrast_adjustment_changed = YES;
    }

    if (resolution_changed || sound_buffering_changed || contrast_adjustment_changed) {
        [self _changeStreamingSetting:new_setting];
    }
}

- (void)changeLightControl:(BOOL)on
{
    if ([self supportsLightControl]) {
        LightControlStatus status = [_delegate turnLightOn:on];

        [_server_state iterateHandlers:^(SWSConnectionHandler *handler) {
            [((ConnectionHandler *)handler) lightStatusChanged:status];
        }];
    }
}

- (void)changeFocusControl:(BOOL)is_auto
{
    FocusControlStatus status = [_delegate changeFocusMode:is_auto];

    [_server_state iterateHandlers:^(SWSConnectionHandler *handler) {
        [((ConnectionHandler *)handler) focusStatusChanged:status];
    }];

    [self _changeStreamingSetting:[_setting_master changePreferAutoFocus:is_auto of:_current_streaming_setting]];
}

- (void)changeAudioGranted:(BOOL)granted
{
    [self _changeStreamingSetting:[_setting_master changeAudioGranted:granted of:_current_streaming_setting]];
}

- (void)changeUseAudio:(BOOL)enable
{
    if (!_current_streaming_setting.audio_granted) {
        WARN(@"Controlling audio without granted");
        return;
    }

    [self _changeStreamingSetting:[_setting_master changeUseAudio:enable of:_current_streaming_setting] withClientNotification:NO];

    [_delegate changeAudioUse:enable];

    [_server_state iterateHandlers:^(SWSConnectionHandler *handler) {
        [((ConnectionHandler *)handler) notifyAudioUseStatus:enable];
    }];
}

#pragma mark -
#pragma mark Setting change: Server


-(void)saveUpnpExternalPort:(uint16_t)port
{
    [self _changeStreamingSetting:[_setting_master changeUpnpExternalPort:port of:_current_streaming_setting] withClientNotification:NO];
}

- (void)resetToDefaultSetting
{
    [_server_state disconnectAll];

    // Special treatments to sensitive flags
    BOOL appstore_begging = _current_streaming_setting.beg_appstore_review;

    StreamingSetting *default_setting = nil;

    [_server_state changePassword:@""]; // XXX: hack

    if (!appstore_begging) {
        default_setting = [_setting_master dropReviewBeggingFlag:_setting_master.default_streaming_setting];
    } else {
        default_setting = _setting_master.default_streaming_setting;
    }

    [self _changeStreamingSetting:default_setting];

    _state = SERVER_STATE_INIT;

    [_delegate wakeUpAudio];
    [_delegate wakeUpVideo];

    [_delegate settingInvalidated];
}

- (float)getCameraFPS
{
    return MAX(1, MIN([_delegate tellMeCameraFPS], _current_streaming_setting.framerate_limit));
}

#pragma mark -
#pragma mark Setting Chane: Dialog

- (void)neverShow60fpsNotice
{
    [self _changeStreamingSetting:[_setting_master drop60fpsNoticeFlag:_current_streaming_setting] withClientNotification:NO];
}

- (void)neverShowReviewBegging
{
    [self _changeStreamingSetting:[_setting_master dropReviewBeggingFlag:_current_streaming_setting] withClientNotification:NO];
}

#pragma mark -
#pragma mark Message to global state: Running

- (void)_updatePowerSavingMode
{
    if (!_power_saving_mode) {
        ++_power_saving_mode_count;

        if (_power_saving_mode_count > POWER_SAVING_MODE_WAIT_COUNT_THRESHOLD) {
            _power_saving_mode = YES;
        }
    } else {
        _power_saving_mode_count = 0;
    }

    if (_power_saving_mode) {
        [_delegate sleepAudio];
        if (!_current_streaming_setting.playback_enabled) {
            [_delegate sleepVideo];
        }
    }
}

- (void)periodicTask
{
    [self _countStreamingConnections];

    [_server_state periodicTask];

    if ([_server_state numConnections] == 0) {
        [_delegate forceLightOff];

        [self _updatePowerSavingMode];
    }
}

- (void)pauseAll
{
    [_delegate forceLightOff];
    [_delegate pauseNow];
}

- (void)startAll
{
    [_delegate startNow];
}

@end
