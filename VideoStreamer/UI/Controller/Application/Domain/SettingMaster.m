//
//  MediaSpecManager.m
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/03/05.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//


#import "SettingMaster.h"
#import <MDWUtils/NSObject+SimpleArchiver.h>
#import <MDWUtils/NSString+Crypto.h>

@interface StreamingSetting() {

}

@property (nonatomic, readwrite) CGSize screen_size;
@property (nonatomic, readwrite) CGSize capture_size;
@property (nonatomic, readwrite) uint8_t quality;
@property (nonatomic, readwrite) uint8_t resolution_level;
@property (nonatomic, readwrite) uint8_t sound_buffering_level;
@property (nonatomic, readwrite) uint8_t contrast_adjustment_level;
@property (nonatomic, readwrite) uint8_t framerate_limit;

@property (nonatomic, readwrite) BOOL playback_enabled;
@property (nonatomic, readwrite) BOOL audio_granted;
@property (nonatomic, readwrite) BOOL use_audio;
@property (nonatomic, readwrite) VSResizingROI *roi;
@property (nonatomic, readwrite) BOOL enable_60fps;
@property (nonatomic, readwrite) BOOL prefer_auto_focus;
@property (nonatomic, readwrite) uint16_t upnp_external_port;
@property (nonatomic, readwrite) BOOL show_60fps_notice;
@property (nonatomic, readwrite) BOOL beg_appstore_review;
@property (nonatomic, readwrite) BOOL url_display_mdns;
@property (nonatomic, readwrite) uint32_t successfull_connection_count;

@end

@implementation StreamingSetting

- (id)copyWithZone:(NSZone *)zone
{
    StreamingSetting *copied = [[self class] new];

    copied.screen_size = _screen_size;
    copied.capture_size = _capture_size;
    copied.quality = _quality;
    copied.resolution_level = _resolution_level;
    copied.sound_buffering_level = _sound_buffering_level;
    copied.contrast_adjustment_level = _contrast_adjustment_level;
    copied.playback_enabled = _playback_enabled;
    copied.audio_granted = _audio_granted;
    copied.use_audio = _use_audio;
    copied.enable_60fps = _enable_60fps;
    copied.framerate_limit = _framerate_limit;
    copied.prefer_auto_focus = _prefer_auto_focus;
    copied.upnp_external_port = _upnp_external_port;
    copied.show_60fps_notice = _show_60fps_notice;
    copied.beg_appstore_review = _beg_appstore_review;
    copied.url_display_mdns = _url_display_mdns;
    copied.successfull_connection_count = _successfull_connection_count;

    copied.roi = [_roi copy];

    return copied;
}
@end

@interface SettingMaster() {
    StreamingSetting *_default_streaming_setting;
}
@end

@implementation SettingMaster

+ (instancetype)sharedMaster
{
    static SettingMaster *__instance;
    static dispatch_once_t __once_token;
    dispatch_once(&__once_token, ^{
        __instance = [[[self class] alloc] init];
        [__instance _setup];
    });
    return __instance;
}

- (StreamingSetting *)_collectDefaultStreamingSetting
{
    StreamingSetting *default_setting = [StreamingSetting new];

    default_setting.screen_size = CGSizeMake(320, 240);
    default_setting.capture_size = CGSizeMake(320, 240);
    default_setting.quality = 70;
    default_setting.contrast_adjustment_level = 0;
    default_setting.sound_buffering_level = 0;
    default_setting.resolution_level = 1;
    default_setting.playback_enabled = YES;
    default_setting.use_audio = YES;
    default_setting.audio_granted = YES;
    default_setting.enable_60fps = NO;
    default_setting.framerate_limit = 30;
    default_setting.roi = [VSResizingROI createDefault];
    default_setting.prefer_auto_focus = YES;
    default_setting.upnp_external_port = 0;
    default_setting.show_60fps_notice = YES;
    default_setting.beg_appstore_review = YES;
    default_setting.url_display_mdns = NO;
    default_setting.successfull_connection_count = 0;

    return default_setting;
}

- (BOOL)_setup
{
    _default_streaming_setting = [self _collectDefaultStreamingSetting];

    return YES;
}

- (StreamingSetting *)changeROI:(VSResizingROI *)roi of:(StreamingSetting *)setting
{
    StreamingSetting *new_setting = [setting copy];

    new_setting.roi = roi;

    return new_setting;
}

- (StreamingSetting *)changeResolutionLevel:(uint8_t)resolution_level of:(StreamingSetting *)setting
{
    StreamingSetting *new_setting = [setting copy];

    new_setting.resolution_level = resolution_level;
    new_setting.capture_size = __determine_capture_size(setting.screen_size, resolution_level, setting.capture_size.width > setting.capture_size.height);

    return new_setting;
}

- (StreamingSetting *)changeOrientationOf:(StreamingSetting *)setting
{
    StreamingSetting *new_setting = [setting copy];

    new_setting.capture_size = CGSizeMake(setting.capture_size.height, setting.capture_size.width);

    return  new_setting;
}

static inline CGSize __determine_capture_size(CGSize screen_size, uint8_t level, bool is_landscape)
{
    int divisor = 1;

    switch (level) {
        case 0: divisor = 4; break;
        case 1: divisor = 2; break;
        case 2: divisor = 1; break;
        default: divisor = 4; break;
    }

    int width = ((int)screen_size.width / divisor) & (~0xf);
    int height = ((int)screen_size.height / divisor) & (~0xf);

    if ((screen_size.width > screen_size.height) != is_landscape) {
        const int tmp = height;
        height = width;
        width = tmp;
    }

    return CGSizeMake(width, height);
}

- (StreamingSetting *)changeScreenSize:(CGSize)screen_size of:(StreamingSetting *)setting
{
    StreamingSetting *new_setting = [setting copy];

    new_setting.screen_size = screen_size;
    new_setting.capture_size = __determine_capture_size(screen_size, setting.resolution_level, setting.capture_size.width > setting.capture_size.height);

    return new_setting;
}

- (StreamingSetting *)changeSoundBufferingLevel:(uint8_t)sound_buffering_level of:(StreamingSetting *)setting
{
    StreamingSetting *new_setting = [setting copy];

    new_setting.sound_buffering_level = sound_buffering_level;

    return new_setting;
}

- (StreamingSetting *)changeContrastAdjustmentLevel:(uint8_t)contrast_adjustment_level of:(StreamingSetting *)setting
{
    StreamingSetting *new_setting = [setting copy];

    new_setting.contrast_adjustment_level = contrast_adjustment_level;

    return new_setting;
}

- (StreamingSetting *)changeQuality:(uint8_t)quality of:(StreamingSetting *)setting
{
    StreamingSetting *new_setting = [setting copy];

    new_setting.quality = quality;

    return new_setting;
}

- (StreamingSetting *)changePlaybackMode:(BOOL)enable of:(StreamingSetting *)setting
{
    StreamingSetting *new_setting = [setting copy];

    new_setting.playback_enabled = enable;

    return new_setting;
}

- (StreamingSetting *)changeAudioGranted:(BOOL)granted of:(StreamingSetting *)setting
{
    StreamingSetting *new_setting = [setting copy];

    new_setting.audio_granted = granted;

    return new_setting;
}

- (StreamingSetting *)changeUseAudio:(BOOL)enable of:(StreamingSetting *)setting
{
    StreamingSetting *new_setting = [setting copy];

    new_setting.use_audio = enable;

    return new_setting;
}

- (StreamingSetting *)changeEnable60fps:(BOOL)enable of:(StreamingSetting *)setting
{
    StreamingSetting *new_setting = [setting copy];

    new_setting.enable_60fps = enable;

    return new_setting;
}

- (StreamingSetting *)changeFramerateLimit:(uint8_t)limit of:(StreamingSetting *)setting
{
    StreamingSetting *new_setting = [setting copy];

    new_setting.framerate_limit = MIN(60, MAX(1, limit));

    return new_setting;
}

- (StreamingSetting *)changePreferAutoFocus:(BOOL)prefer of:(StreamingSetting *)setting
{
    StreamingSetting *new_setting = [setting copy];

    new_setting.prefer_auto_focus = prefer;

    return new_setting;
}

- (StreamingSetting *)changeURLDisplayMDNS:(BOOL)use_mdns of:(StreamingSetting *)setting
{
    StreamingSetting *new_setting = [setting copy];

    new_setting.url_display_mdns = use_mdns;

    return new_setting;
}

- (StreamingSetting *)changeUpnpExternalPort:(uint16_t)port of:(StreamingSetting *)setting
{
    StreamingSetting *new_setting = [setting copy];

    new_setting.upnp_external_port = port;

    return new_setting;
}

- (StreamingSetting *)drop60fpsNoticeFlag:(StreamingSetting *)setting
{
    StreamingSetting *new_setting = [setting copy];

    new_setting.show_60fps_notice = NO;

    return new_setting;
}

- (StreamingSetting *)dropReviewBeggingFlag:(StreamingSetting *)setting
{
    StreamingSetting *new_setting = [setting copy];

    new_setting.beg_appstore_review = NO;

    return new_setting;
}

- (StreamingSetting *)increaseSuccessfullConnectionCount:(StreamingSetting *)setting
{
    StreamingSetting *new_setting = [setting copy];

    new_setting.successfull_connection_count += 1;

    return new_setting;
}

- (BOOL)validateStreamingSetting:(StreamingSetting *)setting
{
    // STUB
    return YES;
}


#pragma mark -
#pragma mark Patial Modifier: Server

#pragma mark -
#pragma mark Persistency

- (NSString *)_genArchiveKey
{
    return NSPRINTF(@"user_setting_%@", [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleVersion"]);
}

- (BOOL)save:(StreamingSetting *)to_save
{
    return [to_save simpleArchiveForKey:[self _genArchiveKey]];
}

- (StreamingSetting *)load
{
    return [StreamingSetting simpleUnarchiveForKey:[self _genArchiveKey]];
}

- (StreamingSetting *)loadOrDefault
{
    StreamingSetting *ret = [self load];

    if (!ret) {
        ret = self.default_streaming_setting;
    }

    return ret;
}

#pragma mark -
#pragma mark Validation

- (BOOL)validateResolutionLevel:(uint8_t)resolution_level of:(StreamingSetting *)setting
{
    EXPECT(resolution_level <= 2, return NO);

    return YES;
}

- (BOOL)validateSoundBufferingLevel:(uint8_t)sound_buffering_level of:(StreamingSetting *)setting
{
    EXPECT(sound_buffering_level <= 2, return NO);

    return YES;
}

- (BOOL)validateContrastAdjustmentLevel:(uint8_t)contrast_adjustment_level of:(StreamingSetting *)setting
{
    EXPECT(contrast_adjustment_level <= 1, return NO);

    return YES;
}

@end
