//
//  MediaStream.m
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/03/03.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import "MediaStreamMessage.h"

@implementation MediaStreamMessage

+ (instancetype)createWithType:(MediaStreamType)type withPayloads:(NSArray *)payloads withTimeStamp:(struct timeval)timestamp
{
    return [[self class] createWithCategory:MESSAGE_CATEGORY_MEDIA_STREAM withType:type withMultiPayload:payloads withTimeStamp:timestamp];
}

+ (instancetype)createMultipartWithType:(MediaStreamType)type withFirstPayloads:(NSArray *)payloads withTimeStamp:(struct timeval)timestamp withSecondPayloadLength:(uint32_t)length
{
    return [[self class] createMultipartWithCategory:MESSAGE_CATEGORY_MEDIA_STREAM withType:type withFirstPayloads:payloads withTimeStamp:timestamp withSecondPayloadLength:length];
}

+ (instancetype)createPCM:(NSData *)payload withTimeStamp:(struct timeval)timestamp
{
    return [[self class] createWithType:MEDIA_STREAM_AUDIO_PCM withPayloads:@[payload] withTimeStamp:(struct timeval)timestamp];
}

static inline NSData *__make_start_codes(int16_t start_sample, int16_t start_index)
{
    uint16_t *p_start_sample = (uint16_t *)&start_sample;
    uint16_t *p_start_index = (uint16_t *)&start_index;

    uint8_t buf[4] = {
        (*p_start_sample >> 8) & 0xFF,
        (*p_start_sample >> 0) & 0xFF,
        (*p_start_index >> 8) & 0xFF,
        (*p_start_index >> 0) & 0xFF,
    };

    return [NSData dataWithBytes:buf length:4];
}

+ (instancetype)createMultipartADPCM:(uint32_t)payload_length
                     withStartSample:(int16_t)start_sample
                      withStartIndex:(int16_t)start_index
                       withTimeStamp:(struct timeval)timestamp
{
    return [[self class] createMultipartWithType:MEDIA_STREAM_AUDIO_ADPCM withFirstPayloads:@[__make_start_codes(start_sample, start_index)] withTimeStamp:(struct timeval)timestamp withSecondPayloadLength:payload_length];
}

+ (instancetype)createMultipartJPEGWithTimeStamp:(struct timeval)timestamp withPayloadLength:(uint32_t)payload_length
{
    return [[self class] createMultipartWithType:MEDIA_STREAM_VIDEO_JPG withFirstPayloads:nil withTimeStamp:timestamp  withSecondPayloadLength:payload_length];
}

// FIXME: delegate to service layer
+ (NSDictionary *)specification_dic
{
    return @{@"MESSAGE_CATEGORY_MEDIA_STREAM":@(MESSAGE_CATEGORY_MEDIA_STREAM),
             @"MEDIA_STREAM_VIDEO_JPG":@(MEDIA_STREAM_VIDEO_JPG),
             @"MEDIA_STREAM_VIDEO_DIFFJPG":@(MEDIA_STREAM_VIDEO_DIFFJPG),
             @"MEDIA_STREAM_AUDIO_PCM":@(MEDIA_STREAM_AUDIO_PCM),
             @"MEDIA_STREAM_AUDIO_ADPCM":@(MEDIA_STREAM_AUDIO_ADPCM),
             @"MEDIA_STREAM_VIDEO_JSMPEG":@(MEDIA_STREAM_VIDEO_JSMPEG),
             @"MEDIA_STREAM_SPEC":@(MEDIA_STREAM_SPEC),
             };
}

+ (NSUInteger)category
{
    return MESSAGE_CATEGORY_MEDIA_STREAM;
}

+ (BOOL)message:(SWSMessage *)message parseForDelegate:(id<OnReadMediaStreamMessageDelegate>)delegate
{
    NSASSERT(!"not impl");
    return NO;
}

- (BOOL)isVideo
{
    BOOL ret = NO;
    switch (_type) {
        case MEDIA_STREAM_VIDEO_JPG: // Fallthrough
        case MEDIA_STREAM_VIDEO_DIFFJPG:
            ret = YES;
            break;
        default:
            break;
    }

    return ret;
}

- (BOOL)isIFrameVideo
{
    BOOL ret = NO;
    switch (_type) {
        case MEDIA_STREAM_VIDEO_JPG:
            ret = YES;
            break;
        default:
            break;
    }

    return ret;
}

- (BOOL)isAudio
{
    BOOL ret = NO;
    switch (_type) {
        case MEDIA_STREAM_AUDIO_ADPCM: // Fallthrough
        case MEDIA_STREAM_AUDIO_PCM:
            ret = YES;
            break;
        default:
            break;
    }

    return ret;
}

@end
