//
//  MainPipeline.h
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/03/03.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MobileCV/MCVDisplayV.h>
#import "GlobalEvent.h"
#import "Domain/Infra/VSVideoCapture.h"
#import "VSMainDisplayV.h" // FIXME: Upper layer reference!
#import <MobileAL/MALRawAudioCapture.h>

@class MainPipeline;

@protocol MainPipelineStateDelegate <NSObject>

@required
- (void)pipeline:(MainPipeline *)pipeline frontCameraEnabledState:(BOOL)enabled;
- (void)pipelineAudioNotGranted;
- (void)pipelineServerCouldNotStart;
- (void)pipelineDimScreenRequest;
- (void)pipelineResetScreenRequest;
- (void)pipelineDidChangeVideoSleepStatus:(BOOL)sleep;

@end

@interface MainPipeline : NSObject<GlobalEventDelegate, VSVideoCaptureDelegate, MALRawAudioCaptureDelegate>

@property (nonatomic, readonly) BOOL running;
@property (nonatomic, weak, readwrite) id<MainPipelineStateDelegate> delegate;

+ (instancetype)createWithMainDisplay:(VSMainDisplayV *)main_display;
+ (instancetype)createWithMainDisplay:(VSMainDisplayV *)main_display withDelegate:(id<MainPipelineStateDelegate>)delegate;

- (BOOL)toggleCameraPosition;
// Forbid explicit pause/start operations
- (void) __unavailable pauseNow;
- (void) __unavailable startNow;

@end
