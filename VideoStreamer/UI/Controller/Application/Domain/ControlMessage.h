//
//  ControlPacket.h
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/03/04.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//


#import <SimpleWebsocketServer/SWSMessage.h>
#import "SettingMaster.h"

#define MESSAGE_CATEGORY_CTRL (0x11)
@interface ControlMessage : SWSMessage

typedef NS_ENUM(NSUInteger, ControlPacketType) {
    CTRL_C2S_QUERY_SPEC = 0x20,
    CTRL_S2C_SHOW_SPEC = 0x21,
    CTRL_C2S_START_STREAMING = 0x22,
    CTRL_C2S_REQUEST_IFRAME = 0x23,

    CTRL_S2C_VIDEO_DISABLED = 0x30,
    CTRL_C2S_REPORT = 0x31,
    CTRL_S2C_REPORT = 0x32,
    CTRL_C2S_AUDIO_ENABLED = 0x40,
    CTRL_C2S_AUDIO_DISABLED = 0x41,
    CTRL_S2C_AUDIO_USE = 0x42,
    CTRL_S2C_AUDIO_UNUSE = 0x43,
    CTRL_C2S_LIGHT_CONTROL = 0x50,
    CTRL_S2C_LIGHT_STATUS = 0x51,
    CTRL_C2S_FOCUS_CONTROL = 0x52,
    CTRL_S2C_FOCUS_STATUS = 0x53,
    CTRL_C2S_CHANGE_ORIENTATION = 0x60,
    CTRL_C2S_SET_LEVELS = 0x61,
    CTRL_C2S_SET_ROI = 0x62,
};

typedef NS_ENUM(NSUInteger, LightControlStatus) {
    LIGHT_CTRL_STATUS_OFF = 0,
    LIGHT_CTRL_STATUS_ON = 1,
    LIGHT_CTRL_STATUS_NONSENSE = 2
};

typedef NS_ENUM(NSUInteger, FocusControlStatus) {
    FOCUS_CTRL_STATUS_MANUAL = 0,
    FOCUS_CTRL_STATUS_AUTO = 1,
    FOCUS_CTRL_STATUS_NONSENSE = 2
};

+ (NSDictionary *)specification_dic;
+ (NSUInteger)_category;
+ (instancetype)createShowSpec:(StreamingSetting *)spec;
+ (instancetype)createReport;
+ (instancetype)createVideoDisabled;
+ (instancetype)createUnuseAudio;
+ (instancetype)createUseAudio;
+ (instancetype)createFocusStatus:(FocusControlStatus)status;
+ (instancetype)createLightStatus:(LightControlStatus)status;
@end

@protocol OnReadControlMessageDelegate<SWSOnReadMessageDelegate>

@required

- (BOOL)onQuerySpec;
- (BOOL)onWaitingInput;
- (BOOL)onStartStreaming;
- (BOOL)onReport:(uint32_t)delta_processed_frames delta_audio_discontinued_count:(uint32_t)delta_audio_discontinued_count delta_video_received_count:(uint32_t)delta_video_received_count audio_redundant_buffer_count:(uint32_t)audio_redundant_buffer_count;
- (BOOL)onLightControl:(BOOL)on;
- (BOOL)onFocusControl:(BOOL)is_auto;
- (BOOL)onRequestIFrame;
- (BOOL)onAudioEnabled;
- (BOOL)onAudioDisabled;
- (BOOL)onChangeOrientation;
- (BOOL)onSetROI:(VSResizingROI *)roi;
- (BOOL)onSetLevels:(uint8_t)resolution_level sound_buffering_level:(uint8_t)sound_buffering_level contrast_adjustment:(uint8_t)contrast_adjustment_level;

@end