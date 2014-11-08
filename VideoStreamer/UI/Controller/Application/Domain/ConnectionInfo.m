//
//  ConnectionInfo.m
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/04/02.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import "ConnectionInfo.h"

@implementation ConnectionInfo

+ (instancetype)create
{
    ConnectionInfo *obj = [[[self class] alloc] init];

    [obj _setup];

    return obj;
}

- (void)_setup
{
    _video_enabled = NO;
    _audio_enabled = NO;
    _bytes_per_second = 0;
    _host = nil;
}

@end
