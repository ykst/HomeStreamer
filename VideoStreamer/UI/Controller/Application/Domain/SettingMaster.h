//
//  MediaSpecManager.h
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/03/05.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NoOuterInit.h"
#import "VSResizingColorConverter.h"

@interface StreamingSetting : NSObject<NSCopying>

@property (nonatomic, readonly) CGSize screen_size;
@property (nonatomic, readonly) CGSize capture_size;
@property (nonatomic, readonly) uint8_t quality;
@property (nonatomic, readonly) uint8_t resolution_level;
@property (nonatomic, readonly) uint8_t sound_buffering_level;
@property (nonatomic, readonly) uint8_t contrast_adjustment_level;
@property (nonatomic, readonly) uint8_t framerate_limit;

@property (nonatomic, readonly) VSResizingROI *roi;
@property (nonatomic, readonly) BOOL playback_enabled;
@property (nonatomic, readonly) BOOL audio_granted;
@property (nonatomic, readonly) BOOL use_audio;
@property (nonatomic, readonly) BOOL enable_60fps;
@property (nonatomic, readonly) BOOL prefer_auto_focus;
@property (nonatomic, readonly) uint16_t upnp_external_port;
@property (nonatomic, readonly) BOOL show_60fps_notice;
@property (nonatomic, readonly) BOOL beg_appstore_review;
@property (nonatomic, readonly) BOOL url_display_mdns;
@property (nonatomic, readonly) uint32_t successfull_connection_count;


@end

@interface SettingMaster : NSObject<NoOuterInit>

@property (nonatomic, readonly) StreamingSetting *default_streaming_setting;
//@property (nonatomic, readonly) StreamingSetting *current_streaming_setting;
+ (instancetype)sharedMaster;
- (BOOL)validateStreamingSetting:(StreamingSetting *)setting;


#pragma mark -
#pragma mark Partial Modifier: Streaming
- (StreamingSetting *)changeROI:(VSResizingROI *)roi of:(StreamingSetting *)setting;
- (StreamingSetting *)changeResolutionLevel:(uint8_t)resolution_level of:(StreamingSetting *)setting;
- (StreamingSetting *)changeSoundBufferingLevel:(uint8_t)sound_buffering_level of:(StreamingSetting *)setting;
- (StreamingSetting *)changeContrastAdjustmentLevel:(uint8_t)contrast_adjustment_level of:(StreamingSetting *)setting;
- (StreamingSetting *)changeOrientationOf:(StreamingSetting *)setting;
- (StreamingSetting *)changeQuality:(uint8_t)quality of:(StreamingSetting *)setting;
- (StreamingSetting *)changePlaybackMode:(BOOL)enable of:(StreamingSetting *)setting;
- (StreamingSetting *)changeAudioGranted:(BOOL)granted of:(StreamingSetting *)setting;
- (StreamingSetting *)changeUseAudio:(BOOL)enable of:(StreamingSetting *)setting;
- (StreamingSetting *)changeEnable60fps:(BOOL)enable of:(StreamingSetting *)setting;
- (StreamingSetting *)changeFramerateLimit:(uint8_t)limit of:(StreamingSetting *)setting;
- (StreamingSetting *)changePreferAutoFocus:(BOOL)prefer of:(StreamingSetting *)setting;
- (StreamingSetting *)changeURLDisplayMDNS:(BOOL)use_mdns of:(StreamingSetting *)setting;
- (StreamingSetting *)changeUpnpExternalPort:(uint16_t)port of:(StreamingSetting *)setting;
- (StreamingSetting *)changeScreenSize:(CGSize)screen_size of:(StreamingSetting *)setting;

- (StreamingSetting *)drop60fpsNoticeFlag:(StreamingSetting *)setting;
;
;
- (StreamingSetting *)dropReviewBeggingFlag:(StreamingSetting *)setting;
- (StreamingSetting *)increaseSuccessfullConnectionCount:(StreamingSetting *)setting;

- (BOOL)validateResolutionLevel:(uint8_t)resolution_level of:(StreamingSetting *)setting;
- (BOOL)validateSoundBufferingLevel:(uint8_t)sound_buffering_level of:(StreamingSetting *)setting;
- (BOOL)validateContrastAdjustmentLevel:(uint8_t)contrast_adjustment_level of:(StreamingSetting *)setting;

#pragma mark -
#pragma mark Persistency
- (BOOL)save:(StreamingSetting *)to_save;
- (StreamingSetting *)load;
- (StreamingSetting *)loadOrDefault;
@end
