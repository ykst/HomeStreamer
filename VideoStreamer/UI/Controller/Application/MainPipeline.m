//
//  MainPipeline.m
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/03/03.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#include <libkern/OSAtomic.h>

#import "MainPipeline.h"

#import <CocoaHTTPServer/HTTPServer.h>
#import <MTPipeline.h>
#import <MobileCV/MCVTexturePassthrough.h>
#import <MobileCV/MCVColorConverter.h>
#import <MobileAL/MALRawAudioFreight.h>
#import <MobileAL/MALEncodedAudioFreight.h>

#import "MainHTTPConnection.h"
#import "MainRenderer.h"

#import "VSCameraBufferFreight.h"
#import "VSRawImageFreight.h"
#import "VSPlanarImageFreight.h"
#import "VSVideoCapture.h"
#import "VSRawAudioCapture.h"
#import "VSResizingColorConverter.h"
#import "VSResizingColorConverterPlanar.h"
#import "VSHistogramEqualizer.h"
#import "VSMainDisplayV.h"
#import "MALAudioADPCMEncoder.h"

#import "MCVJPEGEncoder.h"
#import "MCVImageDifference.h"

#import "MediaStreamMessage.h"
#import <SimpleWebsocketServer/SWSHTTPServer.h>
#import <SimpleWebsocketServer/SWSAbstractFactory.h>

#import "Domain/Infra/fps_calculator.h"
#import "Domain/ConnectionHandler.h"

#define SPINLOCK(lock) for (int ___do = ({ OSSpinLockLock(&(lock)); 1; }); ___do || ({ OSSpinLockUnlock(&(lock)); 0; }); ___do = 0)

@interface MainPipeline() {
    VSVideoCapture *_camera;
    VSRawAudioCapture *_audio;
    MTPipeline *_pipe;
    CGRect _roi;
    SWSHTTPServer *_http_server;
    GlobalEvent *_global_event;


    int _camera_position_idx;

    volatile OSSpinLock _encoded_buf_lock;
    volatile OSSpinLock _timestamp_token_lock;

    BOOL _running;
    BOOL _screen_size_dirty;
    BOOL _device_has_torch;
    BOOL _initial_fps_set;
    BOOL _stream_audio;
    BOOL _audio_sleeping;
    BOOL _video_sleeping;

    CGPoint _focused_point;
    NSMutableSet *_encoded_buf_retains;
    NSSet *_timestamp_retains;
    NSMutableArray *_timestamp_stack;
    NSArray *_camera_positions;
    struct fps_calculator_state _fps_calcurator;
}

@property (nonatomic, readwrite, weak) VSMainDisplayV *main_display;
@property (nonatomic, readwrite) BOOL immediate_iframe;
@property (nonatomic, readwrite) BOOL streaming_roi_changed;
@end

@implementation MTNode(MainPipeline)
- (BOOL)encoderJob:(id (^)(id))block
{
    id src = (id)[self inGet];

    if (!src) return NO;

    id result = block(src);
    if (!result) return NO;

    if (![self outPut:result]) return NO;
    if (![self inPut:src]) return NO;

    return YES;
}
@end

@implementation MainPipeline

+ (instancetype)createWithMainDisplay:(VSMainDisplayV *)main_display
{
    return [[self class] createWithMainDisplay:main_display withDelegate:nil];
}

+ (instancetype)createWithMainDisplay:(VSMainDisplayV *)main_display withDelegate:(id<MainPipelineStateDelegate>)delegate
{
    MainPipeline *obj = [[[self class] alloc] init];

    obj.main_display = main_display;
    obj.main_display.mirror_mode = NO;
    obj.delegate = delegate;
    [obj _setup];

    return obj;
}

- (void)_setup
{
    _global_event = [GlobalEvent sharedMachine];
    _global_event.delegate = self;

    _encoded_buf_lock = OS_SPINLOCK_INIT;
    _encoded_buf_retains = [NSMutableSet set];

    _device_has_torch = [VSVideoCapture hasTorch];
    _stream_audio = _global_event.current_streaming_setting.use_audio;

    [self _setupTimestampTokens];
    [self _setupServer];
    [self _setupPipeline];
    [self _setupInitialCameraState];

    _initial_fps_set = NO;
    fps_calculator_init(&_fps_calcurator);
}

- (void)_setupTimestampTokens
{
    NSMutableArray *timestamp_tokens = [NSMutableArray array];
    for (int i = 0; i < 16; ++i) {
        [timestamp_tokens addObject:[TimestampedData new]];
    }

    _timestamp_token_lock = OS_SPINLOCK_INIT;
    _timestamp_retains = [NSSet setWithArray:timestamp_tokens];
    _timestamp_stack = [NSMutableArray arrayWithArray:timestamp_tokens];
}

- (TimestampedData *)_popTimestampToken
{
    TimestampedData *token = nil;

    SPINLOCK(_timestamp_token_lock) {
        token = [_timestamp_stack lastObject];
        [_timestamp_stack removeLastObject];
    }

    return token;
}

- (void)_pushTimestampToken:(TimestampedData *)token
{
    SPINLOCK(_timestamp_token_lock) {
        [_timestamp_stack addObject:token];
    }
}

- (void)_setupServer
{
    SWSAbstractFactory *_factory = [SWSAbstractFactory sharedFactory];

    _factory.http_connection_class = [MainHTTPConnection class];
    [_factory registerMessageClass:[ControlMessage class]];
    [_factory registerMessageClass:[MediaStreamMessage class]];

    _factory.generateConnectionHandler = ^(SWSConnectionState *connection) {
        return [ConnectionHandler createWithConnection:connection];
    };

    _http_server = [SWSHTTPServer createWithDocRoot:@"Assets/Web"];

    if (_global_event.current_streaming_setting.url_display_mdns) {
        [self _setServerMdns:NO];
    }
}

- (void)_unsetServerMdns
{
    [_http_server forceUnpublishBonjour];

    [_http_server setType:nil];
    [_http_server setName:nil];
}

- (void)_setServerMdns:(BOOL)publish_now
{
    [_http_server setType:@"_http._tcp."];
    [_http_server setName:NSPRINTF(@"Home Streamer (%@)", [NSDate date])];

    if (publish_now) {
        [_http_server republishBonjour];
    }
}

- (void)_setupPipeline
{
    _pipe = [MTPipeline createPipeline];

    [self _setupCamera];
    [self _setupMicrophone];
    [self _setupAudioPipeline];
    [self _setupPlanarVideoPipeline];
    [self _setupMirrorMode:@(_camera.position)];
    [self _invalidateFocusedPoint];
    [self _setFocusModeByCurrentSetting];
    [self changeFocusMode:_global_event.current_streaming_setting.prefer_auto_focus];
}

#pragma mark -
#pragma mark Device
- (void)_setupCamera
{
    [self _resetCameraWithConduit:[_pipe createConduit]];
}

- (void)_resetCameraWithConduit:(MTNode *)conduit
{
    @synchronized(self) {
        MTNode *conduit = [_pipe createConduit];

        if (_global_event.current_streaming_setting.enable_60fps && [VSVideoCapture has60fpsCapability]) {
            _camera = [VSVideoCapture create60FpsWithConduit:conduit];
        } else {
            _camera = [VSVideoCapture createWithConduit:conduit withInputPreset:AVCaptureSessionPresetHigh];
        }

        _camera.delegate = self;

        _screen_size_dirty = YES;
    }
}

- (void)_setupMicrophone
{
    _audio = [VSRawAudioCapture createWithConduit:[_pipe createConduit] withFormat:MAL_RAWAUDIO_FORMAT_PCM_INT16 withDelegate:self];
}

- (void)_syncMain:(dispatch_block_t)block
{
    if (![NSThread isMainThread]) {
        dispatch_sync(dispatch_get_main_queue(), block);
    } else {
        block();
    }
}

/*
- (void)_asyncMain:(dispatch_block_t)block
{
    dispatch_async(dispatch_get_main_queue(), block);
}
 */

#pragma mark -
#pragma mark Audio Pipeline
- (void)_setupAudioPipeline
{
    MTNode *audio_encoder_node = [self _setupAudioEncoderNode];
    const size_t chunk_samples = 1024 * 8;

    [_pipe joint:_audio.conduit to:audio_encoder_node];

    [self _fillInitialBufferInto:audio_encoder_node times:32 with:^{
        return [MALRawAudioFreight createWithSamples:chunk_samples withFormat:MAL_RAWAUDIO_FORMAT_PCM_INT16 withSamplingRate:44100];
    }];
}

#define CONNECTION_AUDIO_BUFFER_UNIT (1024 * 4)
#define CONNECTION_AUDIO_MAXIMUM_BUFFER_LENGTH (8 * CONNECTION_AUDIO_BUFFER_UNIT)

- (uint32_t)_determineAudioBufferSize
{
    uint8_t level = _global_event.current_streaming_setting.sound_buffering_level;

    uint32_t size = CONNECTION_AUDIO_BUFFER_UNIT;

    switch (level) {
        case 0:
            size = CONNECTION_AUDIO_BUFFER_UNIT;
            break;
        case 1:
            size = CONNECTION_AUDIO_MAXIMUM_BUFFER_LENGTH / 2;
            break;
        case 2:
            size = CONNECTION_AUDIO_MAXIMUM_BUFFER_LENGTH;
            break;
        default:
            WARN("illegal sound level: %d", level);
            break;
    }

    return MIN(CONNECTION_AUDIO_MAXIMUM_BUFFER_LENGTH,
               MAX(CONNECTION_AUDIO_BUFFER_UNIT, size));
}

- (MTNode *)_setupAudioEncoderNode
{
    __block MALAudioADPCMEncoder *encoder;
    __block MALEncodedAudioFreight *audio_buffer = nil;
    
    return [_pipe createNodeWithSetup:^(MTNode *node) {
        encoder = [MALAudioADPCMEncoder create];
        return YES;
    } withProcess:^BOOL(MTNode *node) {
        return [node sinkJob:^BOOL(MALRawAudioFreight *src) {

            if (!(_audio.playing) || !_stream_audio || [_global_event currentStreamingConnections] == 0) {
                audio_buffer = nil;
                return YES;
            }

            BOOL need_swap_index = YES;

            if (audio_buffer == nil) {

                audio_buffer =
                    [MALEncodedAudioFreight createWithLength:([self _determineAudioBufferSize])
                                                  withFormat:MAL_ENCODED_AUDIO_FORMAT_ADPCM];

                audio_buffer.timestamp = src.timestamp;

                need_swap_index = NO;
            }

            int16_t start_sample = 0;
            int16_t start_index = 0;

            if (need_swap_index) {
                start_sample = audio_buffer.start_sample;
                start_index = audio_buffer.start_index;
            }

            [encoder process:src to:audio_buffer];

            if (need_swap_index) {
                audio_buffer.start_sample = start_sample;
                audio_buffer.start_index = start_index;
            }

            if (audio_buffer.filled) {
                if ([_global_event currentStreamingConnections] > 0) {
                    [_global_event gotNewEncodedAudio:[audio_buffer retrieveData] withStartSample:audio_buffer.start_sample withStartIndex:audio_buffer.start_index withTimestamp:audio_buffer.timestamp];
                }
                audio_buffer = nil;
            }

            return YES;
        }];
    } withTeardown:nil];
}

#pragma mark -
#pragma mark Video Pipeline
- (void)_setupPlanarVideoPipeline
{
    CGSize encode_size = [SettingMaster sharedMaster].default_streaming_setting.capture_size;

    MTNode *display_ccv_node = [self _setupDisplayCcvNode];
    MTNode *stream_node = [self _setupVideoStreamNode];
    MTNode *encoder_ccv_node = [self _setupEncoderPlanarCcvNode:stream_node];
    MTNode *display_node = [self _setupDisplayNode];

    [_pipe chain:_camera.conduit to:display_ccv_node];
    [_pipe joint:display_ccv_node to:display_node];
    [_pipe extend:display_ccv_node to:encoder_ccv_node];

    const int num_cpus = [NSProcessInfo processInfo].processorCount;
    int num_encoders = MIN(MAX(num_cpus, 1), 2);

    for (int i = 0; i < num_encoders; ++i) {
        MTNode *encoder_node = [self _setupPlanarImageEncoderNode:encode_size];
        [_pipe joint:encoder_ccv_node to:encoder_node];
        [_pipe joint:encoder_node to:stream_node];

        if (i == 0) {
            [self _fillInitialBufferInto:encoder_node times:4 with:^{
                return [VSPlanarImageFreight create420WithSize:encode_size
                                                    withSmooth:NO];
            }];
        }
    }

    [_pipe bind:encoder_ccv_node to:_camera.conduit];

    [self _fillInitialBufferInto:encoder_ccv_node times:4 with:^{
        return [VSCameraBufferFreight create];
    }];

    [self _fillInitialBufferInto:display_node times:3 with:^{
        return [VSRawImageFreight createWithSize:encode_size
                              withInternalFormat:GL_RGBA
                                      withSmooth:YES];
    }];
}

- (MTNode *)_setupEncoderPlanarCcvNode:(MTNode *)stream_node
{
    __block VSResizingColorConverterPlanar *ccv;
    __block EAGLContext *context;
    __block VSHistogramEqualizer *equalizer;

    return [_pipe createNodeWithSetup:^(MTNode *node) {
        context = [TGLDevice setNewContext];

        ccv = [VSResizingColorConverterPlanar create];
        equalizer = [VSHistogramEqualizer create];

        return YES;
    } withProcess:^BOOL(MTNode *node) {

        // short circuit when no listeners are around
        if ([_global_event currentStreamingConnections] == 0) {
            return [node sinkJob:nil];
        }

        [TGLDevice setContext:context];

        return [node jointJob:^(VSRawImageFreight<MCVSubPlanerBufferProtocol> *src, VSPlanarImageFreight *dst) {
            dst.timestamp = src.timestamp;

            BOOL contrast_adjust_on = _global_event.current_streaming_setting.contrast_adjustment_level == 1;
            BOOL roi_dirty = NO;
            CGSize target_size = _global_event.current_streaming_setting.capture_size;

            if (target_size.width != dst.size.width ||
                target_size.height != dst.size.height) {
                [dst resize:target_size];
                roi_dirty = YES;
            }

            VSResizingROI *roi = nil;
            if (_streaming_roi_changed) {
                roi_dirty = YES;
                _streaming_roi_changed = NO;
            }

            if (roi_dirty) {
                if (!roi) {
                    roi = _global_event.current_streaming_setting.roi;
                }
                [ccv setROI:roi];
                // [equalizer setROI:roi]; NOTE: Found full-range is better
            }

            if (contrast_adjust_on) {
                [equalizer updateLUT:src];
            } else if (!equalizer.is_normal) {
                [equalizer setNormalLUT];
            }

            TimestampedData *token = [self _popTimestampToken];
            token.timestamp = src.timestamp;

            [stream_node feedInGet:token];

            return [ccv process:src withLut:(contrast_adjust_on ? equalizer.lut : nil) to:dst];
        }];
    } withTeardown:nil];
}

- (MTNode *)_setupDisplayCcvNode
{
    __block MCVColorConverter *ccv;
    __block EAGLContext *context;

    return [_pipe createNodeWithSetup:^(MTNode *node) {
        context = [TGLDevice setNewContext];

        ccv = [MCVColorConverter createWithType:GLCCV_TYPE_YUV420P_RGBA];

        return YES;
    } withProcess:^BOOL(MTNode *node) {
        if (!_initial_fps_set) {
            dispatch_async(dispatch_get_main_queue(), ^{
                @synchronized(self) {
                    [_camera changeCameraFPS:_global_event.current_streaming_setting.framerate_limit];
                }
            });
            _initial_fps_set = YES;
        }

        if (!_global_event.current_streaming_setting.playback_enabled) {
            return [node sinkJob:nil];
        }

        [TGLDevice setContext:context];

        return [node jointJob:^(MCVBufferFreight<MCVSubPlanerBufferProtocol> *src, MCVBufferFreight *dst) {

            CGSize src_size = src.size;
            CGSize dst_size = dst.size;
            if (src_size.width != dst_size.width ||
                src_size.height != dst_size.height) {
                [dst resize:src_size];
            }

            return [ccv process:src to:dst];
        }];
    } withTeardown:nil];
}

#define RELEASE_ENCODED_BUF(buf) do { \
    NSASSERT(buf != nil); \
    SPINLOCK(_encoded_buf_lock) { [_encoded_buf_retains removeObject:buf]; } \
} while(0)

#define RETAIN_ENCODED_BUF(buf) do { \
    NSASSERT(buf != nil); \
    SPINLOCK(_encoded_buf_lock) { [_encoded_buf_retains addObject:buf]; } \
} while(0)

- (MTNode *)_setupPlanarImageEncoderNode:(CGSize)encode_size;
{
    __block MCVJPEGEncoder *encoder;

    return [_pipe createNodeWithSetup:^(MTNode *node) {
        encoder = [MCVJPEGEncoder create];

        return YES;
    } withProcess:^BOOL(MTNode *node) {
        return [node encoderJob:^id(VSPlanarImageFreight *src) {
            uint8_t quality = _global_event.current_streaming_setting.quality;

            TimestampedData *result = nil;

            ASSERT((result = [encoder process420P:src withQuality:quality]) != NULL, return nil);

            RETAIN_ENCODED_BUF(result);
            
            return result;
        }];
    } withTeardown:nil];
}

- (MTNode *)_setupVideoStreamNode
{
    //__block uint32_t iframe_id = 0;
    __block NSMutableArray *token_list = [NSMutableArray array];
    __block NSMutableArray *freight_list = [NSMutableArray array];

    return [_pipe createNodeWithSetup:^(MTNode *node) {
        return YES;
    } withProcess:^BOOL(MTNode *node) {
        TimestampedData *item = [node inGet];

        if (item == nil) return NO;

        if (item.data != nil) {
            {
                TimestampedData *src = item;
                TimestampedData *found = nil;
                struct timeval src_tv = src.timestamp;
                BOOL is_oldest = YES;
                for (TimestampedData *token in token_list) {
                    struct timeval token_tv = token.timestamp;
                    if (src_tv.tv_sec ==  token_tv.tv_sec &&
                        src_tv.tv_usec == token_tv.tv_usec) {
                        found = token;
                        break;
                    } else {
                        // token_listは必ず古い物からソートされているので、
                        // 先頭で一致しなければこのバッファは最古では無い
                        is_oldest = NO;
                        break;
                    }
                }

                if (!is_oldest) {
                    ASSERT(token_list.count > 1, return NO);
                    [freight_list addObject:src];
                    return YES;
                }
                // reject freight not preceeded by timestamp token
                ASSERT(found != nil, return NO);

                [_global_event gotNewEncodedVideo:src];

                RELEASE_ENCODED_BUF(src);

                [token_list removeObject:found];
                [self _pushTimestampToken:found];
            }

            if (freight_list.count > 0) {
                ASSERT(token_list.count > 0, return NO);

                NSMutableArray *token_tobe_remove = nil;

                for (TimestampedData *token in token_list) {
                    TimestampedData *associated = nil;
                    struct timeval token_tv = token.timestamp;

                    for (TimestampedData *waited in freight_list) {
                        struct timeval waited_tv = waited.timestamp;

                        if (waited_tv.tv_sec == token_tv.tv_sec &&
                            waited_tv.tv_usec == token_tv.tv_usec) {
                            associated = waited;
                            break;
                        }
                    }

                    // token_listは古い順に並んでいるので(ry
                    if (associated == nil) {
                        break;
                    }

                    if (token_tobe_remove == nil) token_tobe_remove = [NSMutableArray array];

                    [token_tobe_remove addObject:token];

                    [freight_list removeObject:associated];
                    [_global_event gotNewEncodedVideo:associated];

                    RELEASE_ENCODED_BUF(associated);
                }

                for (TimestampedData *token in token_tobe_remove) {
                    [token_list removeObject:token];
                    [self _pushTimestampToken:token];
                }
            }

            return YES;
        } else {
            [token_list addObject:item];

            return YES;
        }

        return YES;
    } withTeardown:nil];
}

- (MTNode *)_setupDisplayNode
{
    return [_pipe createNodeWithSetup:^(MTNode *node) {
        return YES;
    } withProcess:^BOOL(MTNode *node) {
        return [node sinkJob:^(VSRawImageFreight *src) {
            return [_main_display drawBuffer:src];
        }];
    } withTeardown:nil];
}

- (void)_fillInitialBufferInto:(MTNode *)node times:(NSInteger)num with:(id (^)())supplyer
{
    for (int i = 0; i < num; ++i) {
        [node inPut:[_pipe retainFreight:supplyer()]];
    }
}

- (void)_pause
{
    if (_running) {
        DBG("pausing pipeline..");

        [_camera stopCapture];
        [_audio pause];
        [_pipe pause];
        [_http_server stop];
        _running = NO;
        _global_event.server_port = 0;
        DBG("pipeline paused");
    }
}

- (void)_start
{
    if (!_running) {
        DBG("starting pipeline..");

        [_pipe start];
        if (!_video_sleeping) {
            [_camera startCapture];
        }
        if (_stream_audio && !_audio_sleeping) {
            [_audio start];
        }
        [_http_server startServer];

        _global_event.server_port = _http_server.listeningPort;
        _running = YES;

        DBG("pipeline started");
    }
}

#pragma mark -
#pragma mark Camera position

- (NSArray *)_countCameraPositions
{
    return [MCVVideoCapture countSupportedPositions];
}

- (NSNumber *)_currentCameraPosition
{
    return @(_camera.position);
}

- (void)_setupMirrorMode:(NSNumber *)position
{
    // TODO: Maybe this is not pipeline's job
    if ([position integerValue] == AVCaptureDevicePositionFront) {
        _main_display.mirror_mode = YES;
    } else {
        _main_display.mirror_mode = NO;
    }
}

- (BOOL)_setCameraPosition:(NSNumber *)position
{
    @synchronized(self) {
        if (_video_sleeping == YES ||  _screen_size_dirty == YES) return NO;

        BOOL was_running = _running;

        [self forceLightOff]; // always disable flash on camera switch

        if (was_running) {
            [_camera stopCapture];
        }

        [self _setupMirrorMode:position];

        MTNode *conduit = _camera.conduit;
        _camera = [VSVideoCapture createWithConduit:conduit withInputPreset:AVCaptureSessionPresetHigh withPosition:position.integerValue];
        _camera.delegate = self;

        if (was_running && !_video_sleeping) {
            [_camera startCapture];
        }

        if ([self supportsLightControl]) {
            [_global_event lightStatusChanged:[self currentLightStatus]];
        }

        [_global_event focusStatusChanged:[self changeFocusMode:_global_event.current_streaming_setting.prefer_auto_focus]];

        _screen_size_dirty = YES;
    }

    return YES;
}

- (void)_notifyFrontCameraEnabledState:(BOOL)enabled
{
    ASSERT([_delegate respondsToSelector:@selector(pipeline:frontCameraEnabledState:)], return);

    [self _syncMain:^{
        [_delegate pipeline:self frontCameraEnabledState:enabled];
    }];
}

- (void)_setupInitialCameraState
{
    _camera_positions = [self _countCameraPositions];

    if ([_camera_positions count] <= 1) {
        [self _notifyFrontCameraEnabledState:NO];
    } else {
        NSNumber *current_position = [self _currentCameraPosition];
        _camera_position_idx = 0;

        for (NSNumber *position in _camera_positions) {
            if (position.integerValue == current_position.integerValue) {
                break;
            }
            ++_camera_position_idx;
        }

        [self _notifyFrontCameraEnabledState:!_global_event.current_streaming_setting.enable_60fps];
    }
}

- (BOOL)toggleCameraPosition
{
    int prev_idx = _camera_position_idx;
    _camera_position_idx = (_camera_position_idx + 1) % _camera_positions.count;

    BOOL camera_changed = [self _setCameraPosition:_camera_positions[_camera_position_idx]];

    if (!camera_changed) {
        // camera is busy at here. rollback the state!
        _camera_position_idx = prev_idx;
    }
    
    return camera_changed;
}

#pragma mark -
#pragma mark Camera Focus

- (void)_setFocusModeByCurrentSetting
{
    StreamingSetting *current_setting = _global_event.current_streaming_setting;

    [self _setFocusModeByROI:current_setting.roi withLandScape:current_setting.capture_size.width > current_setting.capture_size.height];
}

#define NEARLY_EQUAL(x, y, e) (ABS((x) - (y)) < (e))
#define FOCUS_EPSILON (0.001f)
#define FOCUS_MODE_CHANGE_SCALE_THRESHOLD (0.81)

- (void)_setFocusModeByROI:(VSResizingROI *)roi withLandScape:(BOOL)is_landscape
{
    @synchronized(self) {
        if ([_camera focusPointSupported]) {
            if (roi.scale > FOCUS_MODE_CHANGE_SCALE_THRESHOLD) {
                [_camera setAutoFocus];
                [self _invalidateFocusedPoint];
            } else {
                CGPoint roi_center = roi.center;
                CGFloat focus_x = roi.center.x;
                CGFloat focus_y = is_landscape ? roi_center.y : 1.0f - roi_center.y;

                if (!is_landscape) {
                    CGFloat tmp = focus_x;
                    focus_x = focus_y;
                    focus_y = tmp;
                }

                // DBG("(%.2f, %.2f)\n", focus_x, focus_y);

                if (!NEARLY_EQUAL(_focused_point.x, focus_x, FOCUS_EPSILON) || !NEARLY_EQUAL(_focused_point.y, focus_y, FOCUS_EPSILON)) {
                    [_camera setFocusPoint:CGPointMake(focus_x, focus_y)];
                    _focused_point = CGPointMake(focus_x, focus_y);

                }
            }
        }
    }
}

- (void)_invalidateFocusedPoint
{
    _focused_point = CGPointMake(-1, -1);
}

#pragma mark -
#pragma mark Camera Capture Delegate

- (void)onCapture:(MCVBufferFreight<MALTimeStampFreightProtocol> *)freight
{
    if (_screen_size_dirty && _camera.capture_size_available) {
        [_global_event changeScreenSize:freight.size];

        _screen_size_dirty = NO;
        _streaming_roi_changed = YES;
    }

    fps_calculator_update(&_fps_calcurator);
}

#pragma mark -
#pragma mark Audio Capture Delegate

- (BOOL)lastGrantedStatus
{
    return _global_event.current_streaming_setting.audio_granted;
}

- (void)saveCurrentGrantedStatus:(BOOL)granted
{
    [_global_event changeAudioGranted:granted];
}

- (void)permissionNotGranted
{
    [_delegate pipelineAudioNotGranted];
}

#pragma mark -
#pragma mark Global Machine Delegate

- (void)setPlaybackMode:(BOOL)enable
{
    if (enable) {
        [_main_display clearSleepSplash];
    } else {
        [_main_display showSleepSplash];
    }
}

- (BOOL)canSet60fps
{
    return [VSVideoCapture has60fpsCapability];
}

- (BOOL)set60fpsMode:(BOOL)enable
{
    BOOL result = NO;

    if (enable) {
        @synchronized(self) {
            if (_screen_size_dirty == YES) return NO;

            BOOL was_running = _running;

            [self forceLightOff]; // always disable flash on camera switch

            if (was_running) {
                [_camera stopCapture];
            }

            MTNode *conduit = _camera.conduit;

            _camera = [VSVideoCapture create60FpsWithConduit:conduit];
            _camera.delegate = self;

            if (was_running && !_video_sleeping) {
                [_camera startCapture];
            }

            if ([self supportsLightControl]) {
                [_global_event lightStatusChanged:[self currentLightStatus]];
            }

            [_camera changeCameraFPS:_global_event.current_streaming_setting.framerate_limit];

            _screen_size_dirty = YES;
        }
        result = YES;

        [self _notifyFrontCameraEnabledState:NO];
    } else {
        result = [self _setCameraPosition:@(AVCaptureDevicePositionBack)];

        BOOL front_camera_supported = _camera_positions.count > 1;

        [self _notifyFrontCameraEnabledState:front_camera_supported];
    }

    return result;
}

- (void)changeCameraFPS:(int)fps
{
    @synchronized(self) {
        [_camera changeCameraFPS:fps];
    }
}

- (void)forceIFrame
{
    _immediate_iframe = YES;
}

- (BOOL)supportsLightControl
{
    return _device_has_torch;
}

- (float)tellMeCameraFPS
{
    return _fps_calcurator.fps;
}

- (void)dimScreen
{
    [_delegate pipelineDimScreenRequest];
}

- (LightControlStatus)turnLightOn:(BOOL)on
{
    if ([self supportsLightControl] &&
        _camera.position == AVCaptureDevicePositionBack) {
        [MCVVideoCapture turnTorchOn:on];
    }

    return [self currentLightStatus];
}

- (LightControlStatus)currentLightStatus
{
    LightControlStatus status = LIGHT_CTRL_STATUS_NONSENSE;

    if ([self supportsLightControl] &&
        _camera.position == AVCaptureDevicePositionBack) {
        status = [MCVVideoCapture torchIsOn] ? LIGHT_CTRL_STATUS_ON : LIGHT_CTRL_STATUS_OFF;
    }

    return status;
}

- (FocusControlStatus)changeFocusMode:(BOOL)is_auto
{
    FocusControlStatus result = FOCUS_CTRL_STATUS_NONSENSE;

    @synchronized(self) {
        if ([_camera focusPointSupported]) {
            if (is_auto) {
                [self _setFocusModeByCurrentSetting];
                result = FOCUS_CTRL_STATUS_AUTO;
            } else {
                [_camera lockFocus];
                result = FOCUS_CTRL_STATUS_MANUAL;
            }
        }
    }

    return result;
}

- (FocusControlStatus)currentFocusStatus
{
    FocusControlStatus result = FOCUS_CTRL_STATUS_NONSENSE;

    @synchronized(self) {
        if ([_camera focusPointSupported]) {
            result = _global_event.current_streaming_setting.prefer_auto_focus ? FOCUS_CTRL_STATUS_AUTO : FOCUS_CTRL_STATUS_MANUAL;
        }
    }

    return result;
}

- (void)forceLightOff
{
    [self turnLightOn:NO];
}

- (void)changeAudioUse:(BOOL)enable
{
    _stream_audio = enable;

    if (_stream_audio && !_audio_sleeping) {
        [_audio start];
    } else {
        [_audio pause];
    }
}

- (void)changeMdnsMode:(BOOL)use_mdns
{
    if (use_mdns) {
        [self _setServerMdns:YES];
    } else {
        [self _unsetServerMdns];
    }
}

- (void)sleepVideo
{
    @synchronized(self) {
        if (!_video_sleeping &&
            [_camera isCapturing] &&
            !_global_event.current_streaming_setting.playback_enabled) {
            DBG(@"display sleep");
            _video_sleeping = YES;

            [self _syncMain:^{
                [_camera stopCapture];
                [_delegate pipelineDidChangeVideoSleepStatus:YES];
            }];
        }
    }
}

- (void)sleepAudio
{
    @synchronized(self) {
        if (!_audio_sleeping && _stream_audio && _audio.playing) {
            DBG(@"audio sleep");
            _audio_sleeping = YES;

            [self _syncMain:^{
                [_audio pause];
            }];
        }
    }
}

- (void)wakeUpVideo
{
    @synchronized(self) {
        _video_sleeping = NO;

        if (![_camera isCapturing]) {
            DBG(@"display wake up");

            [self _syncMain:^{
                [_camera startCapture];

                // Recover the camera FPS
                _fps_calcurator.last_update_mach_time = mach_absolute_time();

                DBG(@"recovered camera fps %.2f", _fps_calcurator.fps);

                [_delegate pipelineDidChangeVideoSleepStatus:NO];
            }];
        }
    }
}

- (void)wakeUpAudio
{
    @synchronized(self) {
        _audio_sleeping = NO;

        if (!_audio.playing) {
            DBG(@"audio wake up");

            if (_stream_audio) {
                [self _syncMain:^{
                    [_audio start];
                }];
            }
        }
    }
}

- (void)pauseNow
{
    [self _pause];
}

- (void)startNow
{
    [self _start];
}

- (void)roiChanged
{
    _streaming_roi_changed = YES;

    if (_global_event.current_streaming_setting.prefer_auto_focus) {
        [self _setFocusModeByCurrentSetting];
    }
}

- (void)settingInvalidated
{
    _streaming_roi_changed = YES;

    [self _syncMain:^{
        @synchronized(self) {
            [self setPlaybackMode:_global_event.current_streaming_setting.playback_enabled];

            [_delegate pipelineResetScreenRequest];

            // XXX: dirty reinitialization
            [self _setCameraPosition:@(AVCaptureDevicePositionBack)];

            [self changeFocusMode:_global_event.current_streaming_setting.prefer_auto_focus];

            [self changeCameraFPS:_global_event.current_streaming_setting.framerate_limit];

            [self changeAudioUse:_global_event.current_streaming_setting.use_audio];

            [self _setupInitialCameraState];

            _screen_size_dirty = YES;
        }
    }];
}

@end
