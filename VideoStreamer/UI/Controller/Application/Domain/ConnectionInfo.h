//
//  ConnectionInfo.h
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/04/02.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ConnectionInfo : NSObject
@property (nonatomic, readwrite) NSString *host;
@property (nonatomic, readwrite) double bytes_per_second;
@property (nonatomic, readwrite) BOOL video_enabled;
@property (nonatomic, readwrite) BOOL audio_enabled;
@property (nonatomic, readwrite) double client_fps;
+ (instancetype)create;
@end
