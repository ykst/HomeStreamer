//
//  MediaStream.h
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/03/03.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <SimpleWebsocketServer/SWSMessage.h>

#define MESSAGE_CATEGORY_MEDIA_STREAM (0x12)

@interface MediaStreamMessage : SWSMessage

typedef NS_ENUM(NSUInteger, MediaStreamType) {
    MEDIA_STREAM_VIDEO_JPG = 0x10,
    MEDIA_STREAM_VIDEO_DIFFJPG = 0x11,
    MEDIA_STREAM_AUDIO_PCM = 0x20,
    MEDIA_STREAM_AUDIO_ADPCM = 0x21,
    MEDIA_STREAM_VIDEO_JSMPEG = 0x30,
    MEDIA_STREAM_SPEC = 0xF0,
};

+ (NSDictionary *)specification_dic;
+ (instancetype)createPCM:(NSData *)payload withTimeStamp:(struct timeval)timestamp;
+ (instancetype)createMultipartADPCM:(uint32_t)payload_length withStartSample:(int16_t)start_sample withStartIndex:(int16_t)start_index withTimeStamp:(struct timeval)timestamp;
+ (instancetype)createMultipartJPEGWithTimeStamp:(struct timeval)timestamp withPayloadLength:(uint32_t)payload_length;

- (BOOL)isVideo;
- (BOOL)isIFrameVideo;
- (BOOL)isAudio;
@end

@protocol OnReadMediaStreamMessageDelegate<SWSOnReadMessageDelegate>

@optional

@end