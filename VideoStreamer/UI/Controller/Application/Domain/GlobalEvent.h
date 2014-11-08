//
//  GlobalStateMachine.h
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/03/05.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SettingMaster.h"
#import "MediaStreamMessage.h"

#import <MobileAL/MALEncodedAudioFreight.h>
#import "Infra/TimestampedData.h"
#import "ConnectionInfo.h"

#import "ControlMessage.h" // just for LightControlStatus.. bad bad
@protocol GlobalEventDelegate <NSObject>

@required
- (void)settingInvalidated;
- (void)forceIFrame;
- (void)roiChanged;
- (BOOL)supportsLightControl;
- (LightControlStatus)turnLightOn:(BOOL)on;
- (LightControlStatus)currentLightStatus;
- (FocusControlStatus)changeFocusMode:(BOOL)is_auto;
- (FocusControlStatus)currentFocusStatus;
- (void)forceLightOff;
- (void)setPlaybackMode:(BOOL)enable;
- (BOOL)canSet60fps;
- (BOOL)set60fpsMode:(BOOL)enable;
- (void)changeAudioUse:(BOOL)enable;
- (void)pauseNow;
- (void)startNow;
- (float)tellMeCameraFPS;
- (void)changeCameraFPS:(int)fps;
- (void)changeMdnsMode:(BOOL)use_mdns;
- (void)wakeUpVideo;
- (void)wakeUpAudio;
- (void)sleepVideo;
- (void)sleepAudio;

- (void)dimScreen;
@end

@protocol ConnectionEventDelegate <NSObject>

@required

- (void)streamingSpecChanged:(StreamingSetting *)spec;
- (void)newEncodedVideoArrived:(TimestampedData *)video;
- (void)newEncodedAudioArrived:(NSData *)audio_buffer withStartSample:(int16_t)start_sample withStartIndex:(int16_t)start_index withTimestamp:(struct timeval)timestamp;
- (void)lightStatusChanged:(LightControlStatus)status;
- (void)focusStatusChanged:(FocusControlStatus)status;
- (void)notifyAudioUseStatus:(BOOL)enable;
- (BOOL)areYouStreaming;
- (ConnectionInfo *)reportStatistics; // TODO: be more smart struct

@end

@interface GlobalEvent : NSObject

@property (nonatomic, readonly) StreamingSetting *current_streaming_setting;
@property (nonatomic, readwrite, weak) id<GlobalEventDelegate>delegate;
@property (atomic, readwrite) uint16_t server_port;
@property (atomic, readwrite) BOOL upnp_enabled;
@property (atomic, readonly) BOOL power_saving_mode;

+ (instancetype)sharedMachine;

#pragma mark -
#pragma mark Message to global state: Setting query
- (BOOL)supportsLightControl;
- (LightControlStatus)currentLightStatus;
- (FocusControlStatus)currentFocusStatus;
- (void)setPlaybackMode:(BOOL)enable;
- (BOOL)set60FpsMode:(BOOL)enable;
- (void)changeFramerateLimit:(int)limit;
- (BOOL)support60Fps;
- (BOOL)prepareCustomURLCommand:(NSString *)command;
#pragma mark -
#pragma mark Networking
- (void)changeURLType:(BOOL)use_mdns;
- (NSString *)generateCurrentURL;
#pragma mark -
#pragma mark Message to global state: Streaming
- (NSUInteger)currentStreamingConnections;
- (void)prepareForIncomingConnection;
- (void)connectionWillBeginStreaming;
- (void)connectionIsSuccessfull; // for appstore review begging
- (void)requestIFrame;

- (void)gotNewEncodedVideo:(TimestampedData *)video;
- (void)gotNewEncodedAudio:(NSData *)audio_buffer withStartSample:(int16_t)start_sample withStartIndex:(int16_t)start_index withTimestamp:(struct timeval)timestamp;


- (void)lightStatusChanged:(LightControlStatus) status;
- (void)focusStatusChanged:(FocusControlStatus) status;

- (NSArray *)gatherClientStatistics;
#pragma mark -
#pragma mark Setting change: Streaming
- (void)changeOrientation;
- (void)changeScreenSize:(CGSize)screen_size;
- (void)changeROI:(VSResizingROI *)roi;
- (void)changeImageQuality:(int)quality;
- (void)changeLevels:(uint8_t)resolution_level sound_buffering_level:(uint8_t)sound_buffering_level contrast_adjustment:(uint8_t)contrast_adjustment_level;
- (void)changeLightControl:(BOOL)on;
- (void)changeFocusControl:(BOOL)is_auto;
- (void)changeAudioGranted:(BOOL)granted;
- (void)changeUseAudio:(BOOL)enable;

#pragma mark -
#pragma mark Setting change: Server
- (void)saveUpnpExternalPort:(uint16_t)port;
- (void)resetToDefaultSetting;
- (float)getCameraFPS;
#pragma mark -
#pragma mark Setting change: Dialog
- (void)neverShow60fpsNotice;
- (void)neverShowReviewBegging;

#pragma mark -
#pragma mark Message to global state: Running
- (void)pauseAll;
- (void)startAll;
- (void)periodicTask;
@end
