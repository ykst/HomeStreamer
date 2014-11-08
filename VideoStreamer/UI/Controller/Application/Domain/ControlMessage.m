//
//  ControlPacket.m
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/03/04.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#include <CommonCrypto/CommonCrypto.h>
#include <objc/message.h>
#import "ControlMessage.h"
#import "NSData+View.h"

@implementation ControlMessage

// FIXME: delegate to service layer
+ (NSDictionary *)specification_dic
{
    return @{@"MESSAGE_CATEGORY_CTRL":@(MESSAGE_CATEGORY_CTRL),
             @"CTRL_C2S_QUERY_SPEC":@(CTRL_C2S_QUERY_SPEC),
             @"CTRL_S2C_SHOW_SPEC":@(CTRL_S2C_SHOW_SPEC),
             @"CTRL_C2S_REQUEST_IFRAME":@(CTRL_C2S_REQUEST_IFRAME),
             @"CTRL_C2S_START_STREAMING":@(CTRL_C2S_START_STREAMING),
             @"CTRL_C2S_SET_ROI":@(CTRL_C2S_SET_ROI),
             @"CTRL_C2S_SET_LEVELS":@(CTRL_C2S_SET_LEVELS),

             @"CTRL_S2C_VIDEO_DISABLED":@(CTRL_S2C_VIDEO_DISABLED),
             @"CTRL_C2S_AUDIO_ENABLED":@(CTRL_C2S_AUDIO_ENABLED),
             @"CTRL_C2S_AUDIO_DISABLED":@(CTRL_C2S_AUDIO_DISABLED),
             @"CTRL_S2C_AUDIO_USE":@(CTRL_S2C_AUDIO_USE),
             @"CTRL_S2C_AUDIO_UNUSE":@(CTRL_S2C_AUDIO_UNUSE),
             @"CTRL_C2S_CHANGE_ORIENTATION":@(CTRL_C2S_CHANGE_ORIENTATION),

             @"CTRL_C2S_LIGHT_CONTROL":@(CTRL_C2S_LIGHT_CONTROL),
             @"CTRL_S2C_LIGHT_STATUS":@(CTRL_S2C_LIGHT_STATUS),

             @"CTRL_C2S_FOCUS_CONTROL":@(CTRL_C2S_FOCUS_CONTROL),
             @"CTRL_S2C_FOCUS_STATUS":@(CTRL_S2C_FOCUS_STATUS),

             @"CTRL_C2S_REPORT":@(CTRL_C2S_REPORT),
             @"CTRL_S2C_REPORT":@(CTRL_S2C_REPORT),
             };
}

+ (NSUInteger)_category
{
    return MESSAGE_CATEGORY_CTRL;
}

+ (instancetype)createWithType:(ControlPacketType)type withPayload:(NSData *)payload
{
    return [[self class] createWithCategory:MESSAGE_CATEGORY_CTRL withType:type withPayload:payload];
}


#pragma mark -
#pragma mark Message Factory

+ (instancetype)createReport
{
    return [[self class] createWithType:CTRL_S2C_REPORT withPayload:nil];
}

+ (instancetype)createVideoDisabled
{
    return [[self class] createWithType:CTRL_S2C_VIDEO_DISABLED withPayload:nil];
}

+ (instancetype)createUseAudio
{
    return [[self class] createWithType:CTRL_S2C_AUDIO_USE withPayload:nil];
}

+ (instancetype)createUnuseAudio
{
    return [[self class] createWithType:CTRL_S2C_AUDIO_UNUSE withPayload:nil];
}

+ (instancetype)createShowSpec:(StreamingSetting *)spec
{
    return [[self class] createWithType:CTRL_S2C_SHOW_SPEC withPayload:[[self class] _makeSpecPayload:spec]];
}

+ (instancetype)createLightStatus:(LightControlStatus)status
{
    return [[self class] createWithType:CTRL_S2C_LIGHT_STATUS withPayload:[[self class] makePayloadU8:status]];
}

+ (instancetype)createFocusStatus:(FocusControlStatus)status
{
    return [[self class] createWithType:CTRL_S2C_FOCUS_STATUS withPayload:[[self class] makePayloadU8:status]];
}

#define PAYLOAD_SPEC_LENGTH (4 + 4 + 4 + 8)
+ (NSData *)_makeSpecPayload:(StreamingSetting *)spec
{
    CGSize screen_size = spec.screen_size;
    uint16_t screen_width = screen_size.width;
    uint16_t screen_height = screen_size.height;

    CGSize capture_size = spec.capture_size;
    uint16_t capture_width = capture_size.width;
    uint16_t capture_height = capture_size.height;

    VSResizingROI *roi = spec.roi;

    uint16_t screen_roi_x = roi.center.x * 65535.0;
    uint16_t screen_roi_y = roi.center.y * 65535.0;
    uint16_t screen_roi_scale = roi.scale * 65535.0;
    uint16_t screen_roi_degree = roi.degree;

    uint8_t payload[PAYLOAD_SPEC_LENGTH] = {
        screen_width >> 8,
        screen_width & 0xFF,
        screen_height >> 8,
        screen_height & 0xFF,

        capture_width >> 8,
        capture_width & 0xFF,
        capture_height >> 8,
        capture_height & 0xFF,

        spec.quality & 0xFF,
        spec.resolution_level & 0xFF,
        spec.sound_buffering_level & 0xFF,
        spec.contrast_adjustment_level & 0xFF,

        screen_roi_x >> 8,
        screen_roi_x & 0xFF,
        screen_roi_y >> 8,
        screen_roi_y & 0xFF,

        screen_roi_scale >> 8,
        screen_roi_scale & 0xFF,
        screen_roi_degree >> 8,
        screen_roi_degree & 0xFF,
    };

    return [NSData dataWithBytes:payload length:PAYLOAD_SPEC_LENGTH];
}

#define PAYLOAD_REPORT_LENGTH (16)
+ (BOOL)_parseReport:(NSData *)payload for:(id<OnReadControlMessageDelegate>)delegate
{
    EXPECT(payload.length == PAYLOAD_REPORT_LENGTH, return NO);

    const uint32_t delta_processed_frames = [payload uint32At:0];
    const uint32_t delta_video_received_count = [payload uint32At:4];
    const uint32_t delta_audio_discontinued_count = [payload uint32At:8];
    const uint32_t audio_redundant_buffer_count = [payload uint32At:12];

    EXPECT([delegate onReport:delta_processed_frames delta_audio_discontinued_count:delta_audio_discontinued_count delta_video_received_count:delta_video_received_count audio_redundant_buffer_count:audio_redundant_buffer_count], return NO);

    return YES;
}

#define PAYLOAD_SET_ROI_LENGTH (8)
+ (BOOL)_parseSetROI:(NSData *)payload for:(id<OnReadControlMessageDelegate>)delegate
{
    EXPECT(payload.length == PAYLOAD_SET_ROI_LENGTH, return NO);

    VSResizingROI *roi = [VSResizingROI new];

    roi.center = CGPointMake([payload uint16At:0] / 65535.0,
                             [payload uint16At:2] / 65535.0);
    roi.scale = [payload uint16At:4] / 65535.0;
    roi.degree = [payload uint16At:6];

    EXPECT([delegate onSetROI:roi], return NO);

    return YES;
}

#define PAYLOAD_SET_LEVELS_LENGTH (4)
+ (BOOL)_parseSetLevels:(NSData *)payload  for:(id<OnReadControlMessageDelegate>)delegate
{
    EXPECT(payload.length == PAYLOAD_SET_LEVELS_LENGTH, return NO);

    uint8_t resolution_level = [payload uint8At:0];
    uint8_t sound_buffering_level = [payload uint8At:1];
    uint8_t contrast_adjustment_level = [payload uint8At:2];

    EXPECT([delegate onSetLevels:resolution_level sound_buffering_level:sound_buffering_level contrast_adjustment:contrast_adjustment_level], return NO);

    return YES;
}


#define PAYLOAD_LIGHT_CONTROL_LENGTH (1)
+ (BOOL)_parseLightControl:(NSData *)payload  for:(id<OnReadControlMessageDelegate>)delegate
{
    EXPECT(payload.length == PAYLOAD_LIGHT_CONTROL_LENGTH, return NO);

    BOOL on = *((uint8_t *)payload.bytes) != 0;

    EXPECT([delegate onLightControl:on], return NO);

    return YES;
}

#define PAYLOAD_FOCUS_CONTROL_LENGTH (1)
+ (BOOL)_parseFocusControl:(NSData *)payload  for:(id<OnReadControlMessageDelegate>)delegate
{
    EXPECT(payload.length == PAYLOAD_LIGHT_CONTROL_LENGTH, return NO);

    BOOL is_auto = *((uint8_t *)payload.bytes) != 0;

    EXPECT([delegate onFocusControl:is_auto], return NO);

    return YES;
}

#pragma mark -
#pragma mark Message Parse Action Delegate
+ (BOOL)message:(SWSMessage *)message parseForDelegate:(id<OnReadControlMessageDelegate>)delegate
{
    switch (message.type) {
        case CTRL_C2S_QUERY_SPEC:
            EXPECT([[self class] parseNoParam:@selector(onQuerySpec) for:delegate], return NO);
            break;
        case CTRL_C2S_START_STREAMING:
            EXPECT([[self class] parseNoParam:@selector(onStartStreaming) for:delegate], return NO);
            break;
        case CTRL_C2S_AUDIO_ENABLED:
            EXPECT([[self class] parseNoParam:@selector(onAudioEnabled) for:delegate], return NO);
            break;
        case CTRL_C2S_AUDIO_DISABLED:
            EXPECT([[self class] parseNoParam:@selector(onAudioDisabled) for:delegate], return NO);
            break;
        case CTRL_C2S_SET_LEVELS:
            EXPECT([[self class] _parseSetLevels:message.payload for:delegate], return NO);
            break;
        case CTRL_C2S_CHANGE_ORIENTATION:
            EXPECT([[self class] parseNoParam:@selector(onChangeOrientation) for:delegate], return NO);
            break;
        case CTRL_C2S_REPORT:
            EXPECT([delegate respondsToSelector:@selector(onReport:delta_audio_discontinued_count:delta_video_received_count:audio_redundant_buffer_count:)], return NO);
            EXPECT([[self class] _parseReport:message.payload for:delegate], return NO);
            break;
        case CTRL_C2S_LIGHT_CONTROL:
            EXPECT([[self class] _parseLightControl:message.payload for:delegate], return NO);
            break;
        case CTRL_C2S_FOCUS_CONTROL:
            EXPECT([[self class] _parseFocusControl:message.payload for:delegate], return NO);
            break;
        case CTRL_C2S_SET_ROI:
            EXPECT([delegate respondsToSelector:@selector(onSetROI:)], return NO);
            EXPECT([[self class] _parseSetROI:message.payload for:delegate], return NO);
            break;
        case CTRL_C2S_REQUEST_IFRAME:
            EXPECT([[self class] parseNoParam:@selector(onRequestIFrame) for:delegate], return NO);
            break;
        default:
            ASSERT(!"unsupported", return NO);
            break;
    }

    return YES;
}
@end
