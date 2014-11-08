//
//  NSString+Randomize.m
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/03/07.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import "NSString+Randomize.h"

@implementation NSString (Randomize)

static const char __letters[] = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";

static inline char __get_random_alpha_numeric()
{
    return __letters[arc4random() % 62];
}


+ (instancetype)stringWithRandomAlphanum:(NSUInteger)length
{
    char *buf = malloc(length+1);

    for (int i = 0; i < length; ++i) {
        buf[i] = __get_random_alpha_numeric();
    }

    buf[length] = '\0';

    NSString *ret = [[self class] stringWithUTF8String:buf];

    free(buf);

    return ret;
}

@end
