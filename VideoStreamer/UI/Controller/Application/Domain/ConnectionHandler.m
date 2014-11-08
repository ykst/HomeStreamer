//
//  ConnectionStateMachine.m
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/03/05.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#include <objc/message.h>
#include <mach/mach_time.h>

#import <MobileAL/MALRawAudioCapture.h>
#import <MobileAL/MALRawAudioFreight.h>
#import <MobileAL/MALEncodedAudioFreight.h>
#import <SimpleWebsocketServer/SWSPerformanceStatistics.h>

#import "ConnectionHandler.h"


#define AUTHORIZATION_MAX_FAIL_COUNT (5)

#define CONNECTION_TIMEOUT_SEC (5.0f)
#define CONNECTION_VIDEO_PROCESS_TIMEOUT_SEC (1.0f)
#define CONNECTION_AUDIO_ALLOWD_BUFFER_NUM (4)

typedef NS_ENUM(NSUInteger, ServerConnectionState) {
    CONNECTION_STATE_INIT = 0,
    CONNECTION_STATE_WAIT_SPEC = 1,
    CONNECTION_STATE_WAIT_START = 2,
    CONNECTION_STATE_STREAMING = 3,
    CONNECTION_STATE_FINISHED = 4,
};

@interface ConnectionHandler() {
    ServerConnectionState _state;
    GlobalEvent *_global_event;
    SettingMaster *_setting_master;
    ConnectionInfo *_connection_info;
    SWSConnectionState *_connection;

    BOOL _enable_video;
    BOOL _enable_audio;
    BOOL _need_success_report;

    // audio buffer
    uint32_t _audio_server_skip_count;

    // timestamps
    uint64_t _init_mach_time;
    uint64_t _force_iframe_mach_time;
    uint64_t _audio_degraded_mach_time;
    // client report
    uint32_t _elapsed_client_processed_frames;
    uint32_t _elapsed_client_video_received_count;
    uint32_t _elapsed_client_audio_discontinued_count;

    uint32_t _delta_processed_frame;
    uint32_t _delta_client_video_received_count;
    uint32_t _delta_client_audio_discontinued_count;

    uint32_t _elapsed_server_audio_updates;
    uint32_t _saved_server_audio_updates;
    int32_t _delta_server_audio_updates;

    uint32_t _client_audio_redundant_buffer_count;
    uint32_t _elapsed_server_video_updates;
    uint32_t _saved_server_video_updates;
    int32_t _delta_server_video_updates;
    int32_t _elapsed_server_video_transmissions;

    float _target_fps;
    uint64_t _scheduled_transmissin_delta_mach_time;
    uint64_t _next_video_transmission_mach_time;
    int32_t _last_frame_delay;
    uint32_t _report_receive_count;
    int32_t _upgrade_frame;
    BOOL _cooldown_mode;
    int _authorize_fail_count;
}

@end

static mach_timebase_info_data_t __mach_timebase = {};
static uint64_t __ticks_for_second = 0;

static inline double __calc_mach_offset_seconds(uint64_t from, uint64_t to)
{
    uint64_t const nsec =
        ((to - from) * (double)__mach_timebase.numer) / (double)__mach_timebase.denom;

    return nsec / 1e9;
}

@implementation ConnectionHandler

+ (instancetype)createWithConnection:(SWSConnectionState *)connection
{
    ConnectionHandler *obj = [[[self class] alloc] init];

    ASSERT([obj _setupWithConnection:connection], return nil);

    return obj;
}

- (BOOL)_setupWithConnection:(SWSConnectionState *)connection
{
    _setting_master = [SettingMaster sharedMaster];
    _state = CONNECTION_STATE_INIT;

    static dispatch_once_t __once_token;
    dispatch_once(&__once_token, ^{
        mach_timebase_info(&__mach_timebase);
        __ticks_for_second = ((double)__mach_timebase.denom / (double)__mach_timebase.numer) * 1e9;
    });

    _global_event = [GlobalEvent sharedMachine];
    [_global_event prepareForIncomingConnection];

    _connection = connection;
    _connection.handler = self;
    _elapsed_server_audio_updates = 0;
    _saved_server_audio_updates = 0;
    _elapsed_server_video_updates = 0;
    _saved_server_video_updates = 0;

    _audio_degraded_mach_time = 0;
    _audio_server_skip_count = 0;

    _connection_info = [ConnectionInfo create];
    _connection_info.host = connection.host_str;

    _need_success_report = _global_event.current_streaming_setting.beg_appstore_review;
    _enable_audio = NO;

    return YES;
}

- (void)teardown
{
    _state = CONNECTION_STATE_FINISHED;
}

#pragma mark -
#pragma mark Control Packet Delegate

- (void)connectionOnAuthorized
{
    _init_mach_time = mach_absolute_time();
    _force_iframe_mach_time = _init_mach_time;
    _state = CONNECTION_STATE_WAIT_SPEC;
}

- (void)connectionOnFinished
{
    _state = CONNECTION_STATE_FINISHED;

    _enable_audio = NO;
    _enable_video = NO;
}

- (BOOL)onQuerySpec
{
    switch (_state) {
        case CONNECTION_STATE_INIT:
            return NO;
            break;
        case CONNECTION_STATE_WAIT_SPEC:
            _state = CONNECTION_STATE_WAIT_START;
            break;
        default:
            // keep state
            break;
    }

    if ([_global_event supportsLightControl]) {
        [_connection sendIt:[ControlMessage createLightStatus:[_global_event currentLightStatus]]];
    }

    if ([MALRawAudioCapture microphoneAccessGranted]) {
        [self notifyAudioUseStatus:_global_event.current_streaming_setting.use_audio];
    }

    [_connection sendIt:[ControlMessage createFocusStatus:[_global_event currentFocusStatus]]];

    [_connection sendIt:[ControlMessage createShowSpec:_global_event.current_streaming_setting]];

    return YES;
}

- (BOOL)onLightControl:(BOOL)on
{
    EXPECT([_global_event supportsLightControl], return NO);

    [_global_event changeLightControl:on];

    return YES;
}

- (BOOL)onFocusControl:(BOOL)is_auto
{
    [_global_event changeFocusControl:is_auto];

    return YES;
}

- (BOOL)onStartStreaming
{
    EXPECT(_state == CONNECTION_STATE_WAIT_START, return NO);

    _state = CONNECTION_STATE_STREAMING;

    _enable_video = YES;
    _cooldown_mode = NO;
    _target_fps = [_global_event getCameraFPS];
    _scheduled_transmissin_delta_mach_time = __ticks_for_second / _target_fps;
    _last_frame_delay = 0;
    _report_receive_count = 0;
    _upgrade_frame = 0;
    _next_video_transmission_mach_time = mach_absolute_time();
    _audio_degraded_mach_time = _next_video_transmission_mach_time;

    [_global_event connectionWillBeginStreaming];

    // NOTE:
    // 開始時にいきなりvideo disabledすることでクライアントにIフレームを送らせるシーケンスを、
    // 新たなコマンドを追加する事無く実現出来るのでそうなっていた。
    // GOPを使用する場合はクライアントにIフレームを駆動させる事でディレイを最小化することができるが、
    // 全てがIフレームである場合は余分な処理なので今は消す。
    // 今後GOPを利用する事が有ればここに立ち戻ると思われる。
    // _enable_video = NO;
    // [self _sendIt:[ControlMessage createVideoDisabled]];

    return YES;
}

- (BOOL)onChangeOrientation
{
    [_global_event changeOrientation];

    return YES;
}

- (void)            _updateStatistics:(uint32_t)delta_processed_frames
       delta_audio_discontinued_count:(uint32_t)delta_audio_discontinued_count
           delta_video_received_count:(uint32_t)delta_video_received_count
         audio_redundant_buffer_count:(uint32_t)audio_redundant_buffer_count
{
    _elapsed_client_processed_frames += delta_processed_frames;
    _elapsed_client_audio_discontinued_count += delta_audio_discontinued_count;
    _elapsed_client_video_received_count += delta_video_received_count;

    _delta_server_video_updates = _elapsed_server_video_updates - _saved_server_video_updates;
    _delta_server_audio_updates = _elapsed_server_audio_updates - _saved_server_audio_updates;

    _saved_server_video_updates = _elapsed_server_video_updates;
    _saved_server_audio_updates = _elapsed_server_audio_updates;

    _delta_client_audio_discontinued_count = delta_audio_discontinued_count;
    _delta_client_video_received_count = delta_video_received_count;

    _delta_processed_frame = delta_processed_frames;

    _client_audio_redundant_buffer_count = audio_redundant_buffer_count;
}

static inline float __calc_next_target_fps(float current_fps,
                                           float max_fps,
                                           int32_t current_delay,
                                           int32_t last_delay,
                                           int32_t *p_upgrading)
{
    float target_fps = current_fps;

    if (current_delay == last_delay && current_delay > 1) {
        *p_upgrading = 0;

        target_fps = current_fps - 1;
    } else if (current_delay <= 1) {
        if (last_delay == 0) {
            if (*p_upgrading == 0) {
                *p_upgrading = 1;
            } else {
                *p_upgrading *= 2;
            }
            target_fps = current_fps + *p_upgrading;

        } else {
            *p_upgrading = 0;
            target_fps = current_fps + last_delay;
        }
    } else {
        *p_upgrading = 0;

        target_fps = current_fps - (float)((current_delay - last_delay) / 2);
    }

    target_fps = MAX(1.0f, MIN(target_fps, (float)max_fps));

    return target_fps;
}

- (void)_updateStateByReport
{
    uint64_t current_mach_time = mach_absolute_time();

    if (_enable_video &&
        _delta_processed_frame == 0 &&
        _report_receive_count > 3 &&
        __calc_mach_offset_seconds(_force_iframe_mach_time, current_mach_time) > CONNECTION_VIDEO_PROCESS_TIMEOUT_SEC) {
        _enable_video = NO;

        DBG("client video is temporary disabled");
        [_connection sendIt:[ControlMessage createVideoDisabled]];
    } else {
        int32_t frame_delay = _elapsed_server_video_transmissions - _elapsed_client_video_received_count;

#ifdef ENABLE_BENCHMARK
        float prev_fps = _target_fps;
#endif

        float camera_fps = [_global_event getCameraFPS];

        if (frame_delay > camera_fps) {
            _target_fps *= 0.5f;
            _cooldown_mode = YES;
        } else {
            _cooldown_mode = NO;

            _target_fps = __calc_next_target_fps(_target_fps, camera_fps, frame_delay, _last_frame_delay, &_upgrade_frame);
        }

#ifdef ENABLE_BENCHMARK
        if (ABS(prev_fps - _target_fps) >= 1.0f) {
            DBG("%.2f -> %.2f, %d\n", prev_fps, _target_fps, frame_delay);
        }
#endif

        _last_frame_delay = frame_delay;

        _scheduled_transmissin_delta_mach_time = __ticks_for_second / _target_fps;
    }

    if (_client_audio_redundant_buffer_count > CONNECTION_AUDIO_ALLOWD_BUFFER_NUM) {
        DBG("too many audio buffers reported");
        _audio_server_skip_count = CONNECTION_AUDIO_ALLOWD_BUFFER_NUM - 1;
    }

    if (_need_success_report) {
#ifdef DEBUG
#define PROCESSED_FRAMES_THRESHOLD_OF_SUCCESS (30)
#else
#define PROCESSED_FRAMES_THRESHOLD_OF_SUCCESS (300)
#endif
        if (_elapsed_client_processed_frames > PROCESSED_FRAMES_THRESHOLD_OF_SUCCESS) {
            [_global_event connectionIsSuccessfull];
            _need_success_report = NO;
        }
    }

    _report_receive_count += 1;
}

- (BOOL)                onReport:(uint32_t)delta_processed_frames
  delta_audio_discontinued_count:(uint32_t)delta_audio_discontinued_count
      delta_video_received_count:(uint32_t)delta_video_received_count
    audio_redundant_buffer_count:(uint32_t)audio_redundant_buffer_count
{
    [self       _updateStatistics:delta_processed_frames
   delta_audio_discontinued_count:delta_audio_discontinued_count
       delta_video_received_count:delta_video_received_count
     audio_redundant_buffer_count:audio_redundant_buffer_count];

    [self _updateStateByReport];

    [_connection sendIt:[ControlMessage createReport]];

    return YES;
}

- (BOOL)onRequestIFrame
{
    _enable_video = YES;
    _force_iframe_mach_time = mach_absolute_time();

    [_global_event requestIFrame];

    return YES;
}

- (BOOL)onAudioEnabled
{
    DBG("audio enabled");
    _enable_audio = [MALRawAudioCapture microphoneAccessGranted] && _global_event.current_streaming_setting.use_audio;
    return YES;
}

- (BOOL)onAudioDisabled
{
    DBG("audio disabled");
    _enable_audio = NO;
    return YES;
}

- (BOOL)onSetROI:(VSResizingROI *)roi
{
    [_global_event changeROI:roi];

    return YES;
}

- (BOOL)    onSetLevels:(uint8_t)resolution_level
  sound_buffering_level:(uint8_t)sound_buffering_level
    contrast_adjustment:(uint8_t)contrast_adjustment_level
{
    EXPECT([_setting_master validateResolutionLevel:resolution_level
                                                 of:_global_event.current_streaming_setting], return NO);

    EXPECT([_setting_master validateSoundBufferingLevel:sound_buffering_level
                                                     of:_global_event.current_streaming_setting], return NO);

    EXPECT([_setting_master validateContrastAdjustmentLevel:contrast_adjustment_level
                                                         of:_global_event.current_streaming_setting], return NO);

    [_global_event changeLevels:resolution_level
          sound_buffering_level:sound_buffering_level
            contrast_adjustment:contrast_adjustment_level];

    return YES;
}

#pragma mark -
#pragma mark Messages From Server State Machine

- (void)streamingSpecChanged:(StreamingSetting *)spec
{
    [_connection sendIt:[ControlMessage createShowSpec:spec]];
}

- (void)lightStatusChanged:(LightControlStatus)status
{
    [_connection sendIt:[ControlMessage createLightStatus:status]];
}

- (void)focusStatusChanged:(FocusControlStatus)status
{
    [_connection sendIt:[ControlMessage createFocusStatus:status]];
}

- (void)notifyAudioUseStatus:(BOOL)enable
{
    if (enable) {
        [_connection sendIt:[ControlMessage createUseAudio]];
    } else {
        [_connection sendIt:[ControlMessage createUnuseAudio]];
    }
}

- (void)newEncodedVideoArrived:(TimestampedData *)video
{
    if (_state != CONNECTION_STATE_STREAMING) return;

    _elapsed_server_video_updates += 1;

    if (!_enable_video || _cooldown_mode) {
        return;
    }

    MediaStreamMessage *stream;

    const uint64_t current_time = mach_absolute_time();
    double current_time_f64 = current_time / (double)__ticks_for_second;
    double target_time_f64 = _next_video_transmission_mach_time / (double)__ticks_for_second;

    if (current_time_f64 < target_time_f64 - 0.016f) {
        return;
    }

    NSASSERT(_scheduled_transmissin_delta_mach_time != 0);

    if (_next_video_transmission_mach_time + _scheduled_transmissin_delta_mach_time < current_time) {
        _next_video_transmission_mach_time = current_time + (current_time % _scheduled_transmissin_delta_mach_time);
    } else {
        _next_video_transmission_mach_time += _scheduled_transmissin_delta_mach_time;
    }

    stream = [MediaStreamMessage createMultipartJPEGWithTimeStamp:video.timestamp withPayloadLength:video.data.length];

    _elapsed_server_video_transmissions += 1;
    [_connection sendMultiPart:stream withPayload:video.data];
}

- (void)newEncodedAudioArrived:(NSData *)audio_buffer withStartSample:(int16_t)start_sample withStartIndex:(int16_t)start_index withTimestamp:(struct timeval)timestamp
{
    if (_state != CONNECTION_STATE_STREAMING) return;

    if (_audio_server_skip_count > 0) {
        --_audio_server_skip_count;
        return;
    }

    if (!_enable_audio) {
        return;
    }

    _elapsed_server_audio_updates += 1;

    [_connection sendMultiPart:[MediaStreamMessage createMultipartADPCM:audio_buffer.length withStartSample:start_sample withStartIndex:start_index withTimeStamp:timestamp] withPayload:audio_buffer];
}

- (BOOL)areYouStreaming
{
    return _state == CONNECTION_STATE_STREAMING;
}

- (ConnectionInfo *)reportStatistics
{
    _connection_info.video_enabled = _enable_video;
    _connection_info.audio_enabled = _enable_audio;
    _connection_info.bytes_per_second = [_connection.performance_statistics calcCurrentOutputBytesPerSeconds];
    _connection_info.client_fps = _delta_processed_frame;

    return _connection_info;
}

@end
