//
//  VSRawAudioCapture.m
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/03/06.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import <MobileAL/MALRawAudioFreight.h>
#import "VSRawAudioCapture.h"

@implementation VSRawAudioCapture

- (void)appendMetaInfo:(MALRawAudioFreight *)captured_buf
{
    struct timeval tv;
    gettimeofday(&tv, NULL);
    captured_buf.timestamp = tv;
}

@end
